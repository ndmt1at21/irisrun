// swift-tools-version: 6.0
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
    ],
    targets: [
        // Generated from proto/ by `pnpm proto:generate`.
        .target(
            name: "IrisProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]
        ),
        .testTarget(name: "IrisProtocolTests", dependencies: ["IrisProtocol"]),
        // Reads an app's Xcode project and writes a SwiftPM package of it (P1-12).
        .target(name: "IrisBuild"),
        .executableTarget(name: "irisrun-ios-build", dependencies: ["IrisBuild"]),
        .testTarget(name: "IrisBuildTests", dependencies: ["IrisBuild"]),
    ]
)
