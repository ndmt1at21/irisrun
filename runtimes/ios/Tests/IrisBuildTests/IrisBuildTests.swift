import Foundation
@testable import IrisBuild
import Testing

@Test func parsesOldStylePropertyLists() throws {
    let plist = try Plist(parsing: #"""
    // !$*UTF8*$!
    {
        archiveVersion = 1;
        /* a comment */ objects = {
            A1 /* App.swift */ = {isa = PBXFileReference; path = "My App/App.swift"; sourceTree = "<group>"; };
        };
        list = (one, "two \"2\"", three/four.swift, );
        unicode = "caf\U00e9\n";
    }
    """#)
    #expect(plist["archiveVersion"]?.string == "1")
    #expect(plist["objects"]?["A1"]?["path"]?.string == "My App/App.swift")
    #expect(plist["list"]?.strings == ["one", #"two "2""#, "three/four.swift"])
    #expect(plist["unicode"]?.string == "café\n")
    #expect(throws: PlistError.self) { try Plist(parsing: "{ a = b }") }
}

@Test func expandsBuildSettingReferences() {
    let settings = ["TARGET_NAME": "Demo", "SRCROOT": "/src"]
    #expect(expand("$(TARGET_NAME).app", with: settings) == "Demo.app")
    #expect(expand("${SRCROOT}/Info.plist", with: settings) == "/src/Info.plist")
    #expect(expand("$(TARGET_NAME:c99extidentifier) $(MISSING)x", with: settings) == "Demo x")
    #expect(c99Identifier("My App-2") == "My_App_2")
    #expect(c99Identifier("2048") == "_2048")
}

@Test func stripsPreviewsOfBothKinds() {
    let source = """
    import SwiftUI
    struct A: View { var body: some View { Text("{") } }
    #Preview {
        A()
            .frame(width: 10) // }
    }
    @available(iOS 17, *)
    #Preview("Dark") { A() }
    struct A_Previews: PreviewProvider {
        static var previews: some View {
            A()
        }
    }
    private struct Other: View, PreviewProvider { static var previews: some View { A() }; var body: some View { A() } }
    let b = 1
    """
    #expect(strippingPreviews(source) == """
    import SwiftUI
    struct A: View { var body: some View { Text("{") } }
    let b = 1
    """)
}

/// A project with an iOS app, a watch app, a Swift package and a folder that
/// Xcode 16 keeps in step with the disk.
private func makeProject() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "iris-build-\(UUID().uuidString)")
    let files = [
        "App/DemoApp.swift": "import SwiftUI\n@main struct DemoApp: App { var body: some Scene { WindowGroup { Text(\"Hi\") } } }\n#Preview { Text(\"x\") }\n",
        "App/Assets.xcassets/Contents.json": "{}",
        "App/Info.plist": "<plist/>",
        "Shared/Model.swift": "struct Model {}\n",
        "Shared/Excluded.swift": "struct Excluded {}\n",
        "Shared/Localizable.xcstrings": #"""
        {"sourceLanguage": "en", "strings": {
            "Hello": {"localizations": {"vi": {"stringUnit": {"state": "translated", "value": "Xin chào"}}}},
            "%lld books": {"localizations": {"vi": {"variations": {"plural": {
                "one": {"stringUnit": {"value": "%lld cuốn"}}, "other": {"stringUnit": {"value": "%lld cuốn sách"}}}}}}}
        }, "version": "1.0"}
        """#,
        "Watch/WatchApp.swift": "struct WatchApp {}\n",
    ]
    for (path, text) in files {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
    let project = root.appending(path: "Demo.xcodeproj")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try #"""
    // !$*UTF8*$!
    {
        objects = {
            P0 = {isa = PBXProject; mainGroup = G0; targets = (T1, T2); buildConfigurationList = L0; packageReferences = (R1); };
            G0 = {isa = PBXGroup; children = (G1, S1, G2); sourceTree = "<group>"; };
            G1 = {isa = PBXGroup; children = (F1, F2, F3); path = App; sourceTree = "<group>"; };
            F1 = {isa = PBXFileReference; path = DemoApp.swift; sourceTree = "<group>"; };
            F2 = {isa = PBXFileReference; path = Assets.xcassets; sourceTree = "<group>"; };
            F3 = {isa = PBXFileReference; path = Info.plist; sourceTree = "<group>"; };
            G2 = {isa = PBXGroup; children = (F4); path = Watch; sourceTree = "<group>"; };
            F4 = {isa = PBXFileReference; path = WatchApp.swift; sourceTree = "<group>"; };
            S1 = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (E1); path = Shared; sourceTree = "<group>"; };
            E1 = {isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (Excluded.swift); target = T1; };
            B1 = {isa = PBXBuildFile; fileRef = F1; };
            B2 = {isa = PBXBuildFile; fileRef = F2; };
            B4 = {isa = PBXBuildFile; fileRef = F4; };
            Ph1 = {isa = PBXSourcesBuildPhase; files = (B1); };
            Ph2 = {isa = PBXResourcesBuildPhase; files = (B2); };
            Ph4 = {isa = PBXSourcesBuildPhase; files = (B4); };
            T1 = {isa = PBXNativeTarget; name = Demo; productType = "com.apple.product-type.application"; buildPhases = (Ph1, Ph2); buildConfigurationList = L1; fileSystemSynchronizedGroups = (S1); packageProductDependencies = (D1); };
            T2 = {isa = PBXNativeTarget; name = "Demo Watch"; productType = "com.apple.product-type.application"; buildPhases = (Ph4); buildConfigurationList = L2; };
            L0 = {isa = XCConfigurationList; buildConfigurations = (C0); };
            C0 = {isa = XCBuildConfiguration; name = Debug; buildSettings = {SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; IPHONEOS_DEPLOYMENT_TARGET = 17.0; }; };
            L1 = {isa = XCConfigurationList; buildConfigurations = (C1, C1r); };
            C1 = {isa = XCBuildConfiguration; name = Debug; buildSettings = {PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = dev.iris.demo; INFOPLIST_FILE = App/Info.plist; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) FEATURE_X"; INFOPLIST_KEY_CFBundleDisplayName = Demo; }; };
            C1r = {isa = XCBuildConfiguration; name = Release; buildSettings = {PRODUCT_NAME = Wrong; }; };
            L2 = {isa = XCConfigurationList; buildConfigurations = (C2); };
            C2 = {isa = XCBuildConfiguration; name = Debug; buildSettings = {SDKROOT = watchos; }; };
            R1 = {isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/onevcat/Kingfisher.git"; requirement = {kind = upToNextMajorVersion; minimumVersion = 7.0.0; }; };
            D1 = {isa = XCSwiftPackageProductDependency; package = R1; productName = Kingfisher; };
        };
        rootObject = P0;
    }
    """#.write(to: project.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
    return root
}

@Test func readsTheIOSAppTargetOfAProject() throws {
    let root = try makeProject()
    defer { try? FileManager.default.removeItem(at: root) }
    let app = try AppTarget(directory: root)
    #expect(app.name == "Demo", "not the watch app")
    #expect(app.moduleName == "Demo")
    #expect(app.bundleIdentifier == "dev.iris.demo")
    #expect(app.deploymentTarget == "17.0")
    #expect(app.conditions == ["DEBUG", "FEATURE_X"])
    #expect(app.infoPlistKeys["CFBundleDisplayName"] == "Demo")
    #expect(app.sources.map { relative($0, to: root) }.sorted() == ["App/DemoApp.swift", "Shared/Model.swift"])
    #expect(app.resources.map { relative($0, to: root) }.sorted() == ["App/Assets.xcassets", "Shared/Localizable.xcstrings"])
    #expect(app.packages == [XcodeProject.Package(source: .remote(url: "https://github.com/onevcat/Kingfisher.git", requirement: .upToNextMajor("7.0.0")), products: ["Kingfisher"])])
    #expect(app.packages.first?.identity == "Kingfisher")
}

@Test func writesAPackageWithResources() throws {
    let root = try makeProject()
    let out = FileManager.default.temporaryDirectory.appending(path: "iris-package-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: out)
    }
    let app = try AppTarget(directory: root)
    let writer = PackageWriter(openSwiftUI: URL(filePath: "/work/OpenSwiftUI"), renderLibrary: URL(filePath: "/work/target/release"))
    #expect(try writer.write(app, sourceRoot: root, to: out), "@main makes an executable")

    let manifest = try String(contentsOf: out.appending(path: "Package.swift"), encoding: .utf8)
    #expect(manifest.contains(#".package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")"#))
    #expect(manifest.contains(#".product(name: "Kingfisher", package: "Kingfisher")"#))
    #expect(manifest.contains(#".define("FEATURE_X")"#))
    #expect(manifest.contains(".executableTarget("))
    let app_ = try String(contentsOf: out.appending(path: "Sources/Demo/App/DemoApp.swift"), encoding: .utf8)
    #expect(!app_.contains("#Preview"))
    let strings = try String(contentsOf: out.appending(path: "Resources/vi.lproj/Localizable.strings"), encoding: .utf8)
    #expect(strings.contains(#""Hello" = "Xin chào";"#))
    #expect(strings.contains(#""%lld books" = "%lld cuốn sách";"#), "plurals take their other form")
    #expect(FileManager.default.fileExists(atPath: out.appending(path: "Resources/Assets.xcassets/Contents.json").path))
}

@Test func takesEverySwiftFileOfAFolderWithoutAProject() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "iris-folder-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    for path in ["Sample/App.swift", "Sample/Views/List.swift", "SampleTests/AppTests.swift", "Package.swift"] {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: url, atomically: true, encoding: .utf8)
    }
    let app = try AppTarget(directory: root)
    #expect(app.sources.map { relative($0, to: root) } == ["Sample/App.swift", "Sample/Views/List.swift"])
    #expect(app.conditions == ["DEBUG"])
}

@Test func findsFilesWhateverTheCaseOfTheirPath() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "iris-case-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appending(path: "Login/view"), withIntermediateDirectories: true)
    try "".write(to: root.appending(path: "Login/view/LoginView.swift"), atomically: true, encoding: .utf8)
    #expect(existingFile(root.appending(path: "Login/View/LoginView.swift"))?.path == root.appending(path: "Login/view/LoginView.swift").path)
    #expect(existingFile(root.appending(path: "Login/View/Missing.swift")) == nil)
}
