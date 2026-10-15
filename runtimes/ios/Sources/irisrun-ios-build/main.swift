// Turns an iOS app's Xcode project into a SwiftPM package that builds against
// OpenKit, and prints what it found as JSON.
//
//   irisrun-ios-build <app-dir> --out <package-dir> --openswiftui <checkout>
//       --render-lib <dir> [--target <name>] [--configuration <name>]
//
// Without an .xcodeproj the app is every Swift file in <app-dir> but tests.

import Foundation
import IrisBuild

var arguments = Array(CommandLine.arguments.dropFirst())
var options: [String: String] = [:]
var positional: [String] = []
while let argument = arguments.first {
    arguments.removeFirst()
    if argument.hasPrefix("--"), let value = arguments.first {
        options[String(argument.dropFirst(2))] = value
        arguments.removeFirst()
    } else {
        positional.append(argument)
    }
}
guard let app = positional.first, let out = options["out"], let openSwiftUI = options["openswiftui"], let renderLib = options["render-lib"] else {
    FileHandle.standardError.write(Data("usage: irisrun-ios-build <app-dir> --out <package-dir> --openswiftui <checkout> --render-lib <dir> [--target <name>] [--configuration <name>]\n".utf8))
    exit(2)
}

do {
    let directory = URL(filePath: app).standardizedFileURL
    let target = try AppTarget(directory: directory, targetName: options["target"], configuration: options["configuration"] ?? "Debug")
    let writer = PackageWriter(openSwiftUI: URL(filePath: openSwiftUI), renderLibrary: URL(filePath: renderLib))
    let sourceRoot = XcodeProject.find(in: directory).first.map { (try? XcodeProject(contentsOf: $0))?.sourceRoot ?? directory } ?? directory
    let executable = try writer.write(target, sourceRoot: sourceRoot, to: URL(filePath: out))
    let summary: [String: Any] = [
        "name": target.name,
        "module": target.moduleName,
        "executable": executable,
        "bundleIdentifier": target.bundleIdentifier ?? NSNull(),
        "deploymentTarget": target.deploymentTarget ?? NSNull(),
        "sources": target.sources.count,
        "resources": target.resources.map(\.lastPathComponent),
        "packages": target.packages.map { "\($0.identity): \($0.products.joined(separator: ", "))" },
        "warnings": target.warnings,
    ]
    let json = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: json, as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("irisrun-ios-build: \(error)\n".utf8))
    exit(1)
}
