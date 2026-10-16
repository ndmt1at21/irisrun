// swift-tools-version: 6.0
import Foundation
import PackageDescription

let package = Package(
    name: "IrisRuntime",
    products: [
        .library(name: "IrisProtocol", targets: ["IrisProtocol"]),
        .executable(name: "irisrun-ios-build", targets: ["irisrun-ios-build"]),
    ],
    dependencies: [
        // Keep in step with the apple/swift plugin version in buf.gen.yaml.
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.39.0"),
        // 604 is the swift-syntax release for Swift 6.4, as in tools/ios-corpus. An app's package
        // depends on this one next to OpenSwiftUI, whose OpenObservation takes 603 only, so 603
        // stays allowed there; irisrun-ios-build itself resolves to 604.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.0" ..< "605.0.0"),
    ],
    targets: [
        // Generated from proto/ by `pnpm proto:generate`.
        .target(
            name: "IrisProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]
        ),
        .testTarget(name: "IrisProtocolTests", dependencies: ["IrisProtocol"]),
        // Reads an app's Xcode project and writes a SwiftPM package of it (P1-12).
        .target(
            name: "IrisBuild",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .executableTarget(name: "irisrun-ios-build", dependencies: ["IrisBuild"]),
        // Fixtures holds an app's Objective-C, which Linux can't build until it is rewritten.
        .testTarget(name: "IrisBuildTests", dependencies: ["IrisBuild"], exclude: ["Fixtures"]),
    ]
)

// OpenKit's UIKit and the device host it shares with OpenSwiftUI. They draw with Iris's render
// core, and take the CoreGraphics types from the OpenCoreGraphics checkout that OpenSwiftUI
// builds against, so that a file importing both SwiftUI and UIKit sees one CGAffineTransform.
// So they exist on Linux next to the checkouts of Scripts/fetch-openswiftui.sh (Scripts/env.sh
// sets IRISRUN_IOS_WORK), and linking them needs `cargo build -p irisrun-render --release`.
#if os(Linux)
let environment = ProcessInfo.processInfo.environment
let work = environment["IRISRUN_IOS_WORK"] ?? (environment["HOME"] ?? NSHomeDirectory()) + "/.cache/irisrun/p0-05"
let openCoreGraphics = work + "/checkouts/OpenCoreGraphics"
if FileManager.default.fileExists(atPath: openCoreGraphics) {
    package.dependencies += [
        .package(path: "../../crates/render/swift"),
        .package(path: openCoreGraphics),
    ]
    package.products += [
        .library(name: "IrisHost", targets: ["IrisHost"]),
        // IrisQuartzCore is what apps that `import QuartzCore` get; IrisObjC, which every file of
        // an app imports implicitly, has selectors and the Foundation API that takes them.
        .library(name: "OpenUIKit", targets: ["OpenUIKit", "IrisQuartzCore", "IrisObjC"]),
    ]
    package.targets += [
        .target(
            name: "IrisHost",
            dependencies: ["IrisProtocol", .product(name: "IrisRender", package: "swift")]
        ),
        .target(name: "IrisObjC"),
        .target(
            name: "OpenUIKit",
            dependencies: [
                "IrisHost",
                "IrisObjC",
                .product(name: "IrisRender", package: "swift"),
                .product(name: "OpenCoreGraphics", package: "OpenCoreGraphics"),
            ]
        ),
        .target(name: "IrisQuartzCore", dependencies: ["OpenUIKit"]),
        .testTarget(name: "OpenUIKitTests", dependencies: ["OpenUIKit"]),
        // App code that uses UIKit's main-actor API as Swift 5 apps may, built as apps are built.
        .testTarget(
            name: "Swift5AppTests",
            dependencies: ["OpenUIKit"],
            swiftSettings: [.swiftLanguageMode(.v5), .unsafeFlags(["-module-alias", "UIKit=OpenUIKit"])]
        ),
        // IrisBuildTests' fixture app as irisrun-ios-build rewrites it, built as it builds apps.
        .testTarget(
            name: "ObjCRewriteTests",
            dependencies: ["OpenUIKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-module-alias", "UIKit=OpenUIKit", "-Xfrontend", "-import-module", "-Xfrontend", "IrisObjC"]),
            ]
        ),
    ]
}
#endif
