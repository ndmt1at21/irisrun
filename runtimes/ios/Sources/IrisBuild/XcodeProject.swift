import Foundation

/// An Xcode project read from its `project.pbxproj`: targets, the files in
/// them, build settings and Swift packages.
public struct XcodeProject {
    /// The `.xcodeproj` directory.
    public let url: URL
    /// Where `<group>` and `SOURCE_ROOT` paths start: the directory holding
    /// the `.xcodeproj`, unless the project moves it.
    public let sourceRoot: URL
    let objects: [String: [String: Plist]]
    let root: [String: Plist]
    /// Each group's or file's group, for resolving relative paths.
    private let parents: [String: String]

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url.appending(path: "project.pbxproj"), encoding: .utf8)
        let plist = try Plist(parsing: text)
        var objects: [String: [String: Plist]] = [:]
        for (id, object) in plist["objects"]?.dictionary ?? [:] {
            objects[id] = object.dictionary
        }
        guard let rootID = plist["rootObject"]?.string, let root = objects[rootID] else {
            throw PlistError(message: "no root object in \(url.lastPathComponent)", line: 1)
        }
        var parents: [String: String] = [:]
        for (id, object) in objects where object["children"] != nil {
            for child in object["children"]?.strings ?? [] {
                parents[child] = id
            }
        }
        self.url = url
        self.objects = objects
        self.root = root
        self.parents = parents
        let projectDir = root["projectDirPath"]?.string ?? ""
        sourceRoot = projectDir.isEmpty
            ? url.deletingLastPathComponent()
            : url.deletingLastPathComponent().appending(path: projectDir).standardizedFileURL
    }

    public var targets: [Target] {
        (root["targets"]?.strings ?? []).compactMap { id in
            guard let object = objects[id], object["isa"]?.string == "PBXNativeTarget" else { return nil }
            return Target(
                id: id,
                name: object["name"]?.string ?? id,
                productType: object["productType"]?.string ?? ""
            )
        }
    }

    public struct Target: Equatable, Sendable {
        public let id: String
        public let name: String
        public let productType: String

        public var isApplication: Bool { productType == "com.apple.product-type.application" }
    }

    // MARK: Build settings

    /// The settings of a configuration, the target's over the project's,
    /// with `$(inherited)` and references to other settings expanded.
    public func buildSettings(of target: Target, configuration: String = "Debug") -> [String: String] {
        var settings: [String: String] = [
            "TARGET_NAME": target.name,
            "PROJECT_NAME": url.deletingPathExtension().lastPathComponent,
            "SRCROOT": sourceRoot.path,
            "PROJECT_DIR": sourceRoot.path,
            "SOURCE_ROOT": sourceRoot.path,
            "CONFIGURATION": configuration,
            "PLATFORM_NAME": "iphoneos",
            "SDKROOT": "iphoneos",
        ]
        for list in [root["buildConfigurationList"]?.string, objects[target.id]?["buildConfigurationList"]?.string] {
            guard let list, let configurations = objects[list]?["buildConfigurations"]?.strings else { continue }
            let chosen = configurations.first { objects[$0]?["name"]?.string == configuration } ?? configurations.first
            for (key, value) in chosen.flatMap({ objects[$0]?["buildSettings"]?.dictionary }) ?? [:] {
                let inherited = settings[key] ?? ""
                let raw = value.string ?? value.strings.joined(separator: " ")
                settings[key] = raw.replacingOccurrences(of: "$(inherited)", with: inherited)
                    .replacingOccurrences(of: "${inherited}", with: inherited)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        // References between settings, a few levels deep.
        for _ in 0 ..< 4 {
            for (key, value) in settings where value.contains("$") {
                settings[key] = expand(value, with: settings)
            }
        }
        return settings
    }

    // MARK: Files

    /// The file a reference or group points at, or nil for ones outside the
    /// source tree, such as SDK frameworks and build products.
    public func path(of id: String) -> URL? {
        guard let object = objects[id] else { return nil }
        let path = object["path"]?.string
        let base: URL
        switch object["sourceTree"]?.string ?? "<group>" {
        case "<group>":
            if let parent = parents[id] {
                guard let parentPath = self.path(of: parent) else { return nil }
                base = parentPath
            } else {
                base = sourceRoot
            }
        case "SOURCE_ROOT":
            base = sourceRoot
        case "<absolute>":
            base = URL(filePath: "/")
        default:
            return nil
        }
        guard let path, !path.isEmpty else { return base }
        return base.appending(path: path).standardizedFileURL
    }

    /// The files of a target's build phase of `isa`, such as
    /// `PBXSourcesBuildPhase`, each a variant group's own path for localized
    /// files.
    func files(of target: Target, phase isa: String) -> [URL] {
        let phases = (objects[target.id]?["buildPhases"]?.strings ?? []).filter { objects[$0]?["isa"]?.string == isa }
        return phases.flatMap { objects[$0]?["files"]?.strings ?? [] }.flatMap { buildFile -> [URL] in
            guard let reference = objects[buildFile]?["fileRef"]?.string, let object = objects[reference] else { return [] }
            if object["isa"]?.string == "PBXVariantGroup" {
                // Localized copies, such as en.lproj/Localizable.strings.
                return (object["children"]?.strings ?? []).compactMap(path(of:))
            }
            return path(of: reference).map { [$0] } ?? []
        }
    }

    /// The files of the folders Xcode 16 keeps in step with the disk, relative
    /// to nothing: whole paths. A target owns every file of a folder it lists
    /// but those its exception sets name; another target gets just the files
    /// its exception sets name.
    func synchronizedFiles(of target: Target) -> [URL] {
        let owned = Set(objects[target.id]?["fileSystemSynchronizedGroups"]?.strings ?? [])
        let groups = objects.filter { $0.value["isa"]?.string == "PBXFileSystemSynchronizedRootGroup" }
        var files: [URL] = []
        for (id, group) in groups.sorted(by: { $0.key < $1.key }) {
            guard let folder = path(of: id) else { continue }
            let exceptions = Set((group["exceptions"]?.strings ?? []).flatMap { exception -> [String] in
                guard let set = objects[exception], set["target"]?.string == target.id else { return [] }
                return set["membershipExceptions"]?.strings ?? []
            })
            if owned.contains(id) {
                files += leaves(in: folder).filter { !exceptions.contains(relative($0, to: folder)) }
            } else {
                files += exceptions.sorted().map { folder.appending(path: $0) }
            }
        }
        return files
    }

    /// Files under a folder, with bundles such as `.xcassets` as single items.
    private func leaves(in folder: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var leaves: [URL] = []
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                if XcodeProject.bundleExtensions.contains(url.pathExtension) {
                    leaves.append(url)
                    enumerator.skipDescendants()
                }
            } else {
                leaves.append(url)
            }
        }
        return leaves.sorted { $0.path < $1.path }
    }

    /// Directories Xcode treats as one file.
    static let bundleExtensions: Set<String> = ["xcassets", "bundle", "xcdatamodeld", "xcmappingmodel", "docc", "rcproject", "scnassets", "lproj", "playground", "icon"]

    // MARK: Packages

    /// The Swift packages a target uses, with the products it takes from each.
    public func packages(of target: Target) -> [Package] {
        var packages: [String: Package] = [:]
        var order: [String] = []
        for dependency in objects[target.id]?["packageProductDependencies"]?.strings ?? [] {
            guard let product = objects[dependency], let name = product["productName"]?.string else { continue }
            // A product of a package in the same workspace has no reference.
            guard let referenceID = product["package"]?.string, let reference = objects[referenceID] else { continue }
            if packages[referenceID] == nil {
                let source: Package.Source
                if reference["isa"]?.string == "XCLocalSwiftPackageReference" {
                    let path = reference["relativePath"]?.string ?? ""
                    source = .local(sourceRoot.appending(path: path).standardizedFileURL)
                } else {
                    let requirement = reference["requirement"]?.dictionary ?? [:]
                    source = .remote(
                        url: reference["repositoryURL"]?.string ?? "",
                        requirement: Package.Requirement(requirement)
                    )
                }
                packages[referenceID] = Package(source: source, products: [])
                order.append(referenceID)
            }
            // "PackageName:Product" when Xcode names a product of a plugin package.
            let productName = name.split(separator: ":").last.map(String.init) ?? name
            packages[referenceID]?.products.append(productName)
        }
        return order.compactMap { packages[$0] }
    }

    public struct Package: Equatable, Sendable {
        public enum Source: Equatable, Sendable {
            case remote(url: String, requirement: Requirement)
            case local(URL)
        }

        public enum Requirement: Equatable, Sendable {
            case upToNextMajor(String)
            case upToNextMinor(String)
            case exact(String)
            case range(String, String)
            case branch(String)
            case revision(String)

            init(_ plist: [String: Plist]) {
                let minimum = plist["minimumVersion"]?.string ?? "0.0.0"
                switch plist["kind"]?.string {
                case "upToNextMinorVersion": self = .upToNextMinor(minimum)
                case "exactVersion": self = .exact(plist["version"]?.string ?? minimum)
                case "versionRange": self = .range(minimum, plist["maximumVersion"]?.string ?? minimum)
                case "branch": self = .branch(plist["branch"]?.string ?? "main")
                case "revision": self = .revision(plist["revision"]?.string ?? "")
                default: self = .upToNextMajor(minimum)
                }
            }
        }

        public var source: Source
        public var products: [String]

        /// SwiftPM's name for the package: the last part of its URL or path.
        public var identity: String {
            let last: String = switch source {
            case let .remote(url, _): url.split(separator: "/").last.map(String.init) ?? url
            case let .local(path): path.lastPathComponent
            }
            return last.hasSuffix(".git") ? String(last.dropLast(4)) : last
        }
    }
}

/// `$(NAME)` and `${NAME}` replaced by their values; unknown names become empty, as in Xcode.
func expand(_ value: String, with settings: [String: String]) -> String {
    var result = ""
    var rest = Substring(value)
    while let dollar = rest.firstIndex(of: "$") {
        result += rest[..<dollar]
        let after = rest.index(after: dollar)
        guard after < rest.endIndex, let close: Character = ["(": ")", "{": "}"][rest[after]],
              let end = rest[after...].firstIndex(of: close)
        else {
            result.append("$")
            rest = rest[after...]
            continue
        }
        // $(NAME:modifier) keeps NAME and drops the modifier.
        let name = rest[rest.index(after: after) ..< end].split(separator: ":").first.map(String.init) ?? ""
        result += settings[name] ?? ""
        rest = rest[rest.index(after: end)...]
    }
    return result + rest
}

/// The path of `url` inside `folder`, without a leading slash.
func relative(_ url: URL, to folder: URL) -> String {
    let base = folder.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(base) else { return path }
    return String(path.dropFirst(base.count).drop { $0 == "/" })
}
