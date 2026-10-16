import Foundation

/// Writes an app target as a SwiftPM package that builds against OpenKit.
public struct PackageWriter {
    /// The patched OpenSwiftUI checkout.
    public var openSwiftUI: URL
    /// Iris's runtimes/ios, for OpenUIKit, by the path OpenSwiftUI depends on it by.
    public var runtime: URL
    /// Where `libirisrun_render.a` is, for linking an app.
    public var renderLibrary: URL

    public init(openSwiftUI: URL, runtime: URL, renderLibrary: URL) {
        self.openSwiftUI = openSwiftUI
        self.runtime = runtime
        self.renderLibrary = renderLibrary
    }

    /// What `write` made.
    public struct Written {
        public var isExecutable: Bool
        /// What the Objective-C rewrite found and did, by kind.
        public var objc: [String: Int]
    }

    /// Writes `Package.swift`, the app's Swift files without previews, without
    /// Objective-C and adapted for UIKit under `Sources/<module>`, and its
    /// resources under `Resources`, ready to sit next to the executable: the
    /// Info.plist, which Foundation reads there, asset catalogs as they are,
    /// since OpenKit reads their `Contents.json`, and string catalogs turned
    /// into `.lproj` tables.
    @discardableResult
    public func write(_ app: AppTarget, sourceRoot: URL, to package: URL) throws -> Written {
        let fileManager = FileManager.default
        let sources = package.appending(path: "Sources/\(app.moduleName)")
        let resources = package.appending(path: "Resources")
        for directory in [sources, resources] {
            try? fileManager.removeItem(at: directory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let paths = app.sources.map { placement(of: $0, in: sourceRoot) }
        let objc = try ObjCRewriter(files: zip(paths, app.sources).map { path, file in
            (path, strippingPreviews(try String(contentsOf: file, encoding: .utf8)))
        })
        let (rewritten, registration) = objc.rewrite()
        try registration.write(to: sources.appending(path: "_IrisMethodTables.swift"), atomically: true, encoding: .utf8)
        var isExecutable = false
        var made: Set<String> = []
        for (index, file) in app.sources.enumerated() {
            let adapted = adaptingForUIKit(rewritten[index], made: &made)
            isExecutable = isExecutable || file.lastPathComponent == "main.swift"
                || adapted.split(separator: "\n").contains { line in
                    let code = line.drop { $0 == " " || $0 == "\t" }
                    return code.hasPrefix("@main") || code.hasPrefix("@UIApplicationMain")
                }
            let out = sources.appending(path: paths[index])
            try fileManager.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try adapted.write(to: out, atomically: true, encoding: .utf8)
        }

        try app.infoPlist?.write(to: resources.appending(path: "Info.plist"))
        for file in app.resources {
            if file.pathExtension == "xcstrings" {
                try StringCatalog(contentsOf: file).writeTables(to: resources)
                continue
            }
            let out = resources.appending(path: file.lastPathComponent)
            // .lproj folders merge, so every table of a language lands in one.
            if file.pathExtension == "lproj" {
                try fileManager.createDirectory(at: out, withIntermediateDirectories: true)
                for table in (try? fileManager.contentsOfDirectory(at: file, includingPropertiesForKeys: nil)) ?? [] {
                    try? fileManager.removeItem(at: out.appending(path: table.lastPathComponent))
                    try fileManager.copyItem(at: table, to: out.appending(path: table.lastPathComponent))
                }
            } else if fileManager.fileExists(atPath: file.path) {
                try? fileManager.removeItem(at: out)
                try fileManager.copyItem(at: file, to: out)
            }
        }

        try manifest(for: app, executable: isExecutable).write(to: package.appending(path: "Package.swift"), atomically: true, encoding: .utf8)
        return Written(isExecutable: isExecutable, objc: objc.counts)
    }

    /// Where a source goes under `Sources/<module>`: its path in the
    /// project, or `External/` for files outside it.
    private func placement(of file: URL, in sourceRoot: URL) -> String {
        let path = relative(file, to: sourceRoot)
        return path.hasPrefix("/") || path.hasPrefix("..") ? "External/" + file.lastPathComponent : path
    }

    func manifest(for app: AppTarget, executable: Bool) -> String {
        var dependencies = [#".package(path: \#(literal(openSwiftUI.path)))"#, #".package(path: \#(literal(runtime.path)))"#]
        var products = [#".product(name: "OpenSwiftUI", package: "OpenSwiftUI")"#, #".product(name: "OpenUIKit", package: "ios")"#]
        for package in app.packages {
            switch package.source {
            case let .remote(url, requirement):
                dependencies.append(".package(url: \(literal(url)), \(swiftPM(requirement)))")
            case let .local(path):
                dependencies.append(".package(path: \(literal(path.path)))")
            }
            for product in package.products {
                products.append(".product(name: \(literal(product)), package: \(literal(package.identity)))")
            }
        }
        // `import QuartzCore` loads OpenUIKit through a module of its own: one module can't
        // stand for two aliases.
        let aliases = [
            "SwiftUI=OpenSwiftUI", "Observation=OpenObservation", "UIKit=OpenUIKit",
            "CoreGraphics=OpenCoreGraphics", "QuartzCore=IrisQuartzCore",
        ]
        // Every file sees selectors and the Foundation API that takes them, as on Darwin, where
        // Foundation has them from the Objective-C runtime.
        let flags = (aliases.map { #""-module-alias", "\#($0)""# } + [#""-Xfrontend", "-import-module", "-Xfrontend", "IrisObjC""#])
            .joined(separator: ", ")
        let settings = app.conditions.map { ".define(\(literal($0)))" } + [".unsafeFlags([\(flags)])"]
        let list = { (items: [String], indent: String) in items.map { "\(indent)\($0)," }.joined(separator: "\n") }
        return """
        // swift-tools-version: 6.0
        // Generated by irisrun-ios-build from the \(app.name) target; changes are overwritten.
        import PackageDescription

        let package = Package(
            name: \(literal(app.moduleName)),
            dependencies: [
        \(list(dependencies, "        "))
            ],
            targets: [
                .\(executable ? "executableTarget" : "target")(
                    name: \(literal(app.moduleName)),
                    dependencies: [
        \(list(products, "                "))
                    ],
                    swiftSettings: [
        \(list(settings, "                "))
                    ],
                    linkerSettings: [.unsafeFlags(["-L\(renderLibrary.path)"])]
                ),
            ],
            swiftLanguageModes: [.v5]
        )

        """
    }

    private func swiftPM(_ requirement: XcodeProject.Package.Requirement) -> String {
        switch requirement {
        case let .upToNextMajor(version): "from: \(literal(version))"
        case let .upToNextMinor(version): ".upToNextMinor(from: \(literal(version)))"
        case let .exact(version): "exact: \(literal(version))"
        case let .range(lower, upper): "\(literal(lower)) ..< \(literal(upper))"
        case let .branch(branch): "branch: \(literal(branch))"
        case let .revision(revision): "revision: \(literal(revision))"
        }
    }
}

/// A Swift string literal.
func literal(_ string: String) -> String {
    "\"" + string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}

/// A string catalog (`.xcstrings`): per key, its text in each language.
struct StringCatalog {
    let table: String
    /// Language → key → text.
    var languages: [String: [String: String]] = [:]

    init(contentsOf url: URL) throws {
        table = url.deletingPathExtension().lastPathComponent
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
        for (key, entry) in json["strings"] as? [String: Any] ?? [:] {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for (language, localization) in localizations {
                if let text = StringCatalog.text(of: localization) {
                    languages[language, default: [:]][key] = text
                }
            }
        }
    }

    /// A localization's text. Plural and device variations give their
    /// `other` form.
    // ponytail: plurals collapse to `other`; write .stringsdict when apps need them.
    private static func text(of localization: Any) -> String? {
        guard let localization = localization as? [String: Any] else { return nil }
        if let unit = localization["stringUnit"] as? [String: Any] {
            return unit["value"] as? String
        }
        let variations = localization["variations"] as? [String: Any] ?? [:]
        for kind in ["plural", "device"] {
            if let other = (variations[kind] as? [String: Any])?["other"] {
                return text(of: other)
            }
        }
        return nil
    }

    /// Writes `<language>.lproj/<table>.strings` for each language.
    func writeTables(to directory: URL) throws {
        for (language, strings) in languages {
            let lproj = directory.appending(path: "\(language).lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            let lines = strings.keys.sorted().map { "\(literal($0)) = \(literal(strings[$0]!).replacingOccurrences(of: "\n", with: "\\n"));" }
            try (lines.joined(separator: "\n") + "\n").write(to: lproj.appending(path: "\(table).strings"), atomically: true, encoding: .utf8)
        }
    }
}
