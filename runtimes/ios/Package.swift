// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IrisRuntime",
    products: [
        .library(name: "IrisProtocol", targets: ["IrisProtocol"]),
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
    ]
)
