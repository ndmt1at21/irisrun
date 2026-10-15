import Foundation

/// What a build pipeline has to deal with, read from project files without building anything.
struct Inventory: Codable, Sendable {
    var xcodeProjects = 0
    var packageManifests = 0
    var rootPackage = false
    var generator: String?
    var deploymentTargets: Set<String> = []
    var swiftVersions: Set<String> = []
    var toolsVersions: Set<String> = []
    var spm: Set<String> = []
    var localPackages = 0
    var pods: Set<String> = []
    var carthage: Set<String> = []
    var bridgingHeader = false
    /// Counts by kind: m, mm, c, cpp, h, storyboard, launch-storyboard, xib, xcassets, xcstrings,
    /// strings, xcdatamodeld, storekit, metal, intentdefinition, xcframework, framework.
    var files: [String: Int] = [:]
}

private let counted: Set<String> = [
    "m", "mm", "c", "cc", "cpp", "h", "storyboard", "xib", "xcassets", "xcstrings", "strings",
    "xcdatamodeld", "storekit", "metal", "intentdefinition", "xcframework", "framework",
]
// Dependencies, build output and build scripts: not app code.
private let skippedDirectories: Set<String> = [
    ".git", ".build", ".swiftpm", "Pods", "Carthage", "DerivedData", "node_modules", "checkouts",
    "SourcePackages", "Tuist", "BuildTools", "fastlane", "scripts", "Scripts",
]

/// Walks an app checkout: fills the inventory and returns the Swift sources to scan.
func takeInventory(of root: URL) -> (Inventory, [URL]) {
    var inventory = Inventory()
    var sources: [URL] = []
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey])
    while let url = files?.nextObject() as? URL {
        let name = url.lastPathComponent
        let ext = url.pathExtension
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        if isDirectory {
            // Test targets do not ship in the app.
            if skippedDirectories.contains(name) || name.hasSuffix("Tests") {
                files?.skipDescendants()
                continue
            }
            if ext == "xcodeproj" {
                inventory.xcodeProjects += 1
                read(pbxproj: url.appending(path: "project.pbxproj"), into: &inventory)
            }
            if counted.contains(ext) {
                inventory.files[ext, default: 0] += 1
                files?.skipDescendants()
            }
            if ext == "xcodeproj" || ext == "xcworkspace" { files?.skipDescendants() }
            continue
        }
        switch name {
        case "Package.swift":
            inventory.packageManifests += 1
            if url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL { inventory.rootPackage = true }
            read(manifest: url, into: &inventory)
            continue
        case "Podfile":
            let text = contents(url)
            inventory.pods.formUnion(text.matches(of: /(?m)^\s*pod\s+['"]([^'"\/]+)/).map { String($0.1) })
            inventory.deploymentTargets.formUnion(text.matches(of: /platform\s+:ios\s*,\s*['"]([0-9.]+)/).map { String($0.1) })
        case "Cartfile":
            inventory.carthage.formUnion(
                contents(url).matches(of: /(?m)^\s*(?:github|git|binary)\s+"([^"]+)"/).map { identity(String($0.1)) })
        case "project.yml":
            inventory.generator = "XcodeGen"
        case "Project.swift", "Workspace.swift":
            inventory.generator = "Tuist"
            continue
        default:
            break
        }
        if ext == "storyboard", name.localizedCaseInsensitiveContains("launch") {
            inventory.files["launch-storyboard", default: 0] += 1
        } else if counted.contains(ext) {
            inventory.files[ext, default: 0] += 1
        }
        if ext == "swift", !name.hasSuffix("Tests.swift") { sources.append(url) }
    }
    return (inventory, sources)
}

private func read(pbxproj url: URL, into inventory: inout Inventory) {
    let text = contents(url)
    inventory.deploymentTargets.formUnion(text.matches(of: /IPHONEOS_DEPLOYMENT_TARGET = "?([0-9.]+)/).map { String($0.1) })
    inventory.swiftVersions.formUnion(text.matches(of: /SWIFT_VERSION = "?([0-9.]+)/).map { String($0.1) })
    inventory.spm.formUnion(text.matches(of: /repositoryURL = "?([^";]+)/).map { identity(String($0.1)) })
    inventory.localPackages += text.matches(of: /isa = XCLocalSwiftPackageReference;/).count
    if text.contains(/SWIFT_OBJC_BRIDGING_HEADER = "?[^";\s]/) { inventory.bridgingHeader = true }
}

private func read(manifest url: URL, into inventory: inout Inventory) {
    let text = contents(url)
    inventory.toolsVersions.formUnion(text.matches(of: /swift-tools-version:\s*([0-9.]+)/).map { String($0.1) })
    inventory.spm.formUnion(text.matches(of: /\.package\(\s*(?:name:\s*"[^"]*",\s*)?url:\s*"([^"]+)"/).map { identity(String($0.1)) })
    inventory.deploymentTargets.formUnion(text.matches(of: /\.iOS\(\s*\.v(\d+)(?:_(\d+))?/).map { "\($0.1).\($0.2 ?? "0")" })
    inventory.deploymentTargets.formUnion(text.matches(of: /\.iOS\(\s*"([0-9.]+)"/).map { String($0.1) })
}

/// `https://github.com/onevcat/Kingfisher.git` -> `kingfisher`.
func identity(_ url: String) -> String {
    var name = url.split(separator: "/").last.map(String.init) ?? url
    for suffix in [".git", ".json"] where name.hasSuffix(suffix) { name.removeLast(suffix.count) }
    return name.lowercased()
}

func contents(_ url: URL) -> String {
    (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) } ?? ""
}
