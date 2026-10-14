// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ios-corpus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ios-corpus", targets: ["IOSCorpus"]),
    ],
    dependencies: [
        // The 604.x line is the swift-syntax release for Swift 6.4.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "IOSCorpus",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .testTarget(name: "IOSCorpusTests", dependencies: ["IOSCorpus"]),
    ]
)
