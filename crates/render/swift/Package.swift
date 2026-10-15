// swift-tools-version: 6.0
// Swift bindings for the render core in crates/render, and a demo that draws
// the screens of examples/ios-swiftui through them.
//
// Build the Rust static library first and pass its directory to the linker:
//   cargo build -p irisrun-render --release
//   swift build -Xlinker -L<repo>/target/release
import PackageDescription

let package = Package(
    name: "IrisRender",
    products: [
        .library(name: "IrisRender", targets: ["IrisRender"]),
    ],
    targets: [
        .systemLibrary(name: "CIrisRender"),
        .target(
            name: "IrisRender",
            dependencies: ["CIrisRender"],
            // What libirisrun_render.a needs from the system. On macOS Skia
            // uses CoreText instead; that build is not tried yet.
            linkerSettings: ["fontconfig", "freetype", "stdc++"].map {
                .linkedLibrary($0, .when(platforms: [.linux]))
            }
        ),
        .executableTarget(name: "render-demo", dependencies: ["IrisRender"]),
    ]
)
