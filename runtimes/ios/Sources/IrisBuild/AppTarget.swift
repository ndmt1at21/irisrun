import Foundation

/// What it takes to build an iOS app target: its sources, resources,
/// packages and the settings that change how Swift compiles it.
public struct AppTarget: Sendable {
    public var name: String
    /// The Swift module the sources make, as `PRODUCT_MODULE_NAME`.
    public var moduleName: String
    public var bundleIdentifier: String?
    public var deploymentTarget: String?
    /// Swift files.
    public var sources: [URL]
    /// C, C++ and Objective-C files, which Iris does not build yet.
    public var otherSources: [URL]
    /// Asset catalogs, string catalogs, `.lproj` files, fonts and other
    /// files copied into the app.
    public var resources: [URL]
    public var packages: [XcodeProject.Package]
    /// `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, such as `DEBUG`.
    public var conditions: [String]
    /// `Info.plist` keys Xcode generates from `INFOPLIST_KEY_*` settings.
    public var infoPlistKeys: [String: String]
    /// The Info.plist Xcode puts in the app, as XML.
    public var infoPlist: Data?
    /// Things the build leaves out or may get wrong.
    public var warnings: [String]

    /// Picks the iOS app target of the first project in `directory` that has
    /// one, or the one named `targetName`.
    public init(directory: URL, targetName: String? = nil, configuration: String = "Debug") throws {
        let projects = XcodeProject.find(in: directory)
        var failures: [String] = []
        for projectURL in projects {
            let project = try XcodeProject(contentsOf: projectURL)
            let candidates = project.targets.filter { target in
                guard target.isApplication else { return false }
                if let targetName { return target.name == targetName }
                return project.isIOS(target, configuration: configuration)
            }
            // The target named like the project is the main app more often than not.
            let projectName = projectURL.deletingPathExtension().lastPathComponent
            guard let target = candidates.first(where: { $0.name == projectName }) ?? candidates.first else {
                failures.append("\(projectURL.lastPathComponent): no iOS app target")
                continue
            }
            self.init(project: project, target: target, configuration: configuration)
            return
        }
        guard projects.isEmpty else { throw BuildError(message: failures.joined(separator: "; ")) }
        self.init(folder: directory)
    }

    /// An app with no Xcode project: every Swift file under `directory` but
    /// tests and dependencies, and the resources next to them. Its Info.plist is the one in the
    /// folder, if any, with the keys Xcode generates for a new app, the scene manifest among them.
    public init(folder directory: URL) {
        name = directory.lastPathComponent
        moduleName = c99Identifier(name)
        (bundleIdentifier, deploymentTarget) = (nil, nil)
        (packages, conditions, infoPlistKeys, warnings) = ([], ["DEBUG"], [:], [])
        (sources, otherSources, resources) = ([], [], [])
        var infoPlistFile: URL?
        let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        while let file = enumerator?.nextObject() as? URL {
            let name = file.lastPathComponent
            if ["Pods", "Carthage", "DerivedData", ".build"].contains(name) || name.hasSuffix("Tests") {
                enumerator?.skipDescendants()
            } else if XcodeProject.bundleExtensions.contains(file.pathExtension) {
                resources.append(file)
                enumerator?.skipDescendants()
            } else if file.pathExtension == "swift", name != "Package.swift" {
                sources.append(file)
            } else if ["xcstrings", "ttf", "otf", "json"].contains(file.pathExtension) {
                resources.append(file)
            } else if name == "Info.plist", infoPlistFile == nil {
                infoPlistFile = file
            }
        }
        sources.sort { $0.path < $1.path }
        // As Xcode's app templates set it (GENERATE_INFOPLIST_FILE): SwiftUI apps run in scenes.
        // ponytail: a UIKit app of this kind that makes its window in the app delegate needs an
        // Info.plist with a manifest of its own, or none.
        let settings = ["PRODUCT_NAME": name, "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES"]
        infoPlist = Self.infoPlist(file: infoPlistFile, settings: settings, moduleName: moduleName)
    }

    public init(project: XcodeProject, target: XcodeProject.Target, configuration: String = "Debug") {
        let settings = project.buildSettings(of: target, configuration: configuration)
        name = target.name
        let product = settings["PRODUCT_MODULE_NAME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? settings["PRODUCT_NAME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? target.name
        moduleName = c99Identifier(product)
        bundleIdentifier = settings["PRODUCT_BUNDLE_IDENTIFIER"]
        deploymentTarget = settings["IPHONEOS_DEPLOYMENT_TARGET"]
        conditions = (settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] ?? "")
            .split(separator: " ").map(String.init).filter { !$0.isEmpty && $0 != "$(inherited)" }
        infoPlistKeys = settings.filter { $0.key.hasPrefix("INFOPLIST_KEY_") }
            .reduce(into: [:]) { $0[String($1.key.dropFirst("INFOPLIST_KEY_".count))] = $1.value }
        packages = project.packages(of: target)
        warnings = []

        let infoPlist = settings["INFOPLIST_FILE"].map { project.sourceRoot.appending(path: $0).standardizedFileURL }
        self.infoPlist = Self.infoPlist(file: infoPlist, settings: settings, moduleName: moduleName)
        var sources: [URL] = []
        var otherSources: [URL] = []
        var resources: [URL] = []
        var seen: Set<URL> = []
        let compiled = project.files(of: target, phase: "PBXSourcesBuildPhase")
        let copied = project.files(of: target, phase: "PBXResourcesBuildPhase")
        for file in compiled + copied + project.synchronizedFiles(of: target) {
            guard seen.insert(file).inserted, file != infoPlist else { continue }
            switch file.pathExtension {
            case "swift": sources.append(file)
            case "m", "mm", "c", "cc", "cpp", "metal": otherSources.append(file)
            case "h", "hpp", "plist", "entitlements", "xcconfig", "md", "docc", "modulemap", "pch": continue
            default: resources.append(file)
            }
        }
        self.sources = sources
        self.otherSources = otherSources
        self.resources = resources

        if !otherSources.isEmpty {
            warnings.append("\(otherSources.count) C or Objective-C files are left out")
        }
        if let header = settings["SWIFT_OBJC_BRIDGING_HEADER"], !header.isEmpty {
            warnings.append("the Objective-C bridging header \(header) is ignored")
        }
        let interfaceFiles = self.resources.flatMap { file in
            file.pathExtension == "lproj"
                ? (try? FileManager.default.contentsOfDirectory(at: file, includingPropertiesForKeys: nil)) ?? []
                : [file]
        }.filter { ["storyboard", "xib"].contains($0.pathExtension) && !$0.lastPathComponent.lowercased().contains("launch") }
        if !interfaceFiles.isEmpty {
            warnings.append("\(interfaceFiles.count) storyboards or XIBs need Interface Builder support, which OpenKit lacks")
        }
        // Xcode finds a path whatever its case, as macOS does; Linux doesn't.
        self.sources = sources.compactMap(existingFile)
        self.resources = resources.compactMap(existingFile)
        let missing = sources.filter { existingFile($0) == nil }
        if !missing.isEmpty {
            warnings.append("\(missing.count) Swift files in the project are missing on disk, such as \(relative(missing[0], to: project.sourceRoot))")
        }
    }
}

extension AppTarget {
    /// The target's Info.plist file with the keys Xcode adds: the bundle's own and those it
    /// generates from `INFOPLIST_KEY_*` settings, with build settings in its strings expanded,
    /// such as the `$(PRODUCT_MODULE_NAME).SceneDelegate` of a scene manifest.
    // ponytail: generated keys are strings and booleans, and of the `_Generation` flags only
    // the scene manifest's, which apps run by; the others and the per-device variants (`_iPhone`,
    // `_iPad`) are left out until something reads them.
    static func infoPlist(file: URL?, settings: [String: String], moduleName: String) -> Data? {
        var info = file.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] } ?? [:]
        var settings = settings
        settings["PRODUCT_MODULE_NAME"] = moduleName
        settings["EXECUTABLE_NAME"] = moduleName
        settings["DEVELOPMENT_LANGUAGE"] = settings["DEVELOPMENT_LANGUAGE"] ?? "en"
        settings["PRODUCT_BUNDLE_PACKAGE_TYPE"] = settings["PRODUCT_BUNDLE_PACKAGE_TYPE"] ?? "APPL"
        var generated = [
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleExecutable": "$(EXECUTABLE_NAME)",
            "CFBundleName": "$(PRODUCT_NAME)",
            "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
            "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
            "CFBundleShortVersionString": "$(MARKETING_VERSION)",
            "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        ]
        for (key, value) in settings where key.hasPrefix("INFOPLIST_KEY_") {
            let name = String(key.dropFirst("INFOPLIST_KEY_".count))
            if !name.hasSuffix("_Generation"), !name.hasSuffix("_iPhone"), !name.hasSuffix("_iPad") {
                generated[name] = value
            }
        }
        func expanded(_ value: Any) -> Any {
            switch value {
            case let string as String: expand(string, with: settings)
            case let array as [Any]: array.map(expanded)
            case let dictionary as [String: Any]: dictionary.mapValues(expanded)
            default: value
            }
        }
        for (key, value) in generated where info[key] == nil {
            let value = expand(value, with: settings)
            if value == "YES" || value == "NO" {
                info[key] = value == "YES"
            } else if !value.isEmpty {
                info[key] = value
            }
        }
        // The manifest that puts the app in scenes, as Xcode writes it for SwiftUI apps, whose
        // app delegate gives the configurations.
        if expand(settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] ?? "", with: settings) == "YES",
           info["UIApplicationSceneManifest"] == nil {
            info["UIApplicationSceneManifest"] = ["UIApplicationSupportsMultipleScenes": true]
        }
        return try? PropertyListSerialization.data(fromPropertyList: expanded(info), format: .xml, options: 0)
    }
}

public struct BuildError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

extension XcodeProject {
    /// `.xcodeproj` directories under `directory`, shallowest first, leaving
    /// out CocoaPods' and those inside other bundles.
    public static func find(in directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        var projects: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            switch url.pathExtension {
            case "xcodeproj":
                if url.deletingPathExtension().lastPathComponent != "Pods" { projects.append(url) }
                enumerator?.skipDescendants()
            case "xcworkspace", "xcassets", "bundle", "app", "framework":
                enumerator?.skipDescendants()
            default:
                if ["Pods", "Carthage", "DerivedData", ".build", "node_modules"].contains(url.lastPathComponent) {
                    enumerator?.skipDescendants()
                }
            }
        }
        return projects.sorted { ($0.pathComponents.count, $0.path) < ($1.pathComponents.count, $1.path) }
    }

    /// Whether a target builds for iOS rather than macOS, watchOS or tvOS.
    func isIOS(_ target: Target, configuration: String) -> Bool {
        let settings = buildSettings(of: target, configuration: configuration)
        let platforms = (settings["SUPPORTED_PLATFORMS"] ?? "").split(separator: " ").map(String.init)
        if !platforms.isEmpty { return platforms.contains("iphoneos") }
        return (settings["SDKROOT"] ?? "iphoneos") == "iphoneos"
    }
}

/// The file at `url`, each part of its path matched regardless of case when
/// the exact one is missing, or nil.
func existingFile(_ url: URL) -> URL? {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) { return url }
    var found = URL(filePath: "/")
    for part in url.standardizedFileURL.pathComponents.dropFirst() {
        let exact = found.appending(path: part)
        if fileManager.fileExists(atPath: exact.path) {
            found = exact
        } else if let match = (try? fileManager.contentsOfDirectory(atPath: found.path))?.first(where: { $0.lowercased() == part.lowercased() }) {
            found = found.appending(path: match)
        } else {
            return nil
        }
    }
    return found
}

/// A name usable as a Swift module: letters, digits and underscores, not
/// starting with a digit, as Xcode makes `PRODUCT_MODULE_NAME`.
func c99Identifier(_ name: String) -> String {
    var identifier = String(name.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII ? Character(scalar) : "_"
    })
    if identifier.first?.isNumber ?? true { identifier = "_" + identifier }
    return identifier
}
