import Foundation

struct Corpus: Codable {
    let catalog: String
    let apps: [CorpusApp]
}

struct CorpusApp: Codable, Sendable {
    let id, name, repo, commit, license, ui: String
    let tags: [String]
    let why: String
}

struct CompileResult: Codable {
    let ok: Bool
    let seconds: Int
}

@main
struct IOSCorpus {
    static let usage = """
        usage: ios-corpus fetch <corpus.json> <apps-dir>
               ios-corpus analyze <corpus.json> <apps-dir> <out-dir> [--report <report.md>]
               ios-corpus compile <corpus.json> <apps-dir> <out-dir> <command> [args...]
        """

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 3 else { exit(usage) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(filePath: args[1])))
        let apps = URL(filePath: args[2])
        switch args[0] {
        case "fetch" where args.count == 3:
            await fetch(corpus.apps, into: apps)
        case "analyze" where args.count == 4 || (args.count == 6 && args[4] == "--report"):
            let report = args.count == 6 ? URL(filePath: args[5]) : nil
            try await analyze(corpus, apps: apps, out: URL(filePath: args[3]), report: report)
        case "compile" where args.count >= 5:
            try compile(corpus.apps, apps: apps, out: URL(filePath: args[3]), command: Array(args[4...]))
        default:
            exit(usage)
        }
    }

    static func exit(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        Foundation.exit(2)
    }
}

// MARK: fetch

/// Analysis and compilation need text files only; media, fonts, archives and binaries dominate size.
private let sparseCheckout = """
    /*
    !*.png
    !*.PNG
    !*.jpg
    !*.JPG
    !*.jpeg
    !*.gif
    !*.heic
    !*.webp
    !*.svg
    !*.pdf
    !*.psd
    !*.sketch
    !*.mp3
    !*.mp4
    !*.mov
    !*.m4a
    !*.m4v
    !*.aac
    !*.wav
    !*.caf
    !*.ttf
    !*.otf
    !*.ttc
    !*.zip
    !*.ipa
    !*.a
    !*.dylib
    !*.bin
    !*.mlmodel
    !*.scn
    !*.usdz
    !*.reality
    !*.rotato
    !*.sqlite
    !**/*.framework/*
    **/*.framework/Info.plist

    """

func fetch(_ apps: [CorpusApp], into root: URL) async {
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    await withTaskGroup(of: String.self) { group in
        for app in apps {
            group.addTask {
                do {
                    return "\(app.id): \(try fetch(app, into: root.appending(path: app.id)))"
                } catch {
                    return "\(app.id): FAILED \(error)"
                }
            }
        }
        for await line in group { print(line) }
    }
}

/// Shallow, blobless, sparse checkout of the pinned commit.
private func fetch(_ app: CorpusApp, into directory: URL) throws -> String {
    let path = directory.path
    if FileManager.default.fileExists(atPath: path) {
        if (try? run(["git", "-C", path, "rev-parse", "HEAD"])) == app.commit { return "up to date" }
    } else {
        try run(["git", "init", "-q", path])
        try run(["git", "-C", path, "remote", "add", "origin", app.repo])
        try run(["git", "-C", path, "config", "core.sparseCheckout", "true"])
        try sparseCheckout.write(to: directory.appending(path: ".git/info/sparse-checkout"), atomically: true, encoding: .utf8)
    }
    try run(["git", "-C", path, "fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", app.commit])
    try run(["git", "-C", path, "checkout", "-q", "--detach", app.commit])
    return "fetched"
}

// MARK: analyze

func analyze(_ corpus: Corpus, apps root: URL, out: URL, report: URL?) async throws {
    let present = corpus.apps.compactMap { app -> (CorpusApp, Inventory, [URL])? in
        let directory = root.appending(path: app.id)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("\(app.id): not fetched, skipped")
            return nil
        }
        let (inventory, sources) = takeInventory(of: directory)
        return (app, inventory, sources)
    }
    let facts = await withTaskGroup(of: (Int, FileFacts).self) { group in
        for (index, entry) in present.enumerated() {
            for source in entry.2 { group.addTask { (index, scan(source: contents(source))) } }
        }
        var facts = Array(repeating: [FileFacts](), count: present.count)
        for await (index, file) in group { facts[index].append(file) }
        return facts
    }
    let results = present.indices.map { analyze(id: present[$0].0.id, ui: present[$0].0.ui, files: facts[$0], inventory: present[$0].1) }

    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(results).write(to: out.appending(path: "results.json"))
    let compiled = try? JSONDecoder().decode([String: CompileResult].self, from: Data(contentsOf: out.appending(path: "compile.json")))
    let sections = reportSections(corpus: corpus, results: results, compiled: compiled)
    let tables = sections.map { "<!-- generated:\($0.0) -->\n\($0.1)\n<!-- /generated:\($0.0) -->" }.joined(separator: "\n\n")
    try (tables + "\n").write(to: out.appending(path: "tables.md"), atomically: true, encoding: .utf8)
    if let report { try splice(sections, into: report) }
    print("analyzed \(results.count) apps, \(results.reduce(0) { $0 + $1.swiftFiles }) Swift files -> \(out.path)")
}

// MARK: compile

/// Hook for P0-05: runs `command... <app-dir>` per app; exit status 0 counts as compiled.
/// Output goes to `<out>/compile/<id>.log`, the summary to `<out>/compile.json` for `analyze`.
func compile(_ apps: [CorpusApp], apps root: URL, out: URL, command: [String]) throws {
    let logs = out.appending(path: "compile")
    try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    var results: [String: CompileResult] = [:]
    for app in apps {
        let directory = root.appending(path: app.id)
        guard FileManager.default.fileExists(atPath: directory.path) else { continue }
        let start = Date()
        let ok = (try? run(command + [directory.path], log: logs.appending(path: "\(app.id).log"))) != nil
        results[app.id] = CompileResult(ok: ok, seconds: Int(Date().timeIntervalSince(start)))
        print("\(app.id): \(ok ? "ok" : "failed")")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(results).write(to: out.appending(path: "compile.json"))
    print("compiled \(results.values.filter(\.ok).count)/\(results.count)")
}

// MARK: processes

struct CommandFailure: Error, CustomStringConvertible {
    let description: String
}

@discardableResult
func run(_ arguments: [String], log: URL? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/env")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    if let log { try data.write(to: log) }
    let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0 else {
        throw CommandFailure(description: "\(arguments.joined(separator: " ")) exited \(process.terminationStatus): \(output)")
    }
    return output
}
