import Foundation
import IrisHost
import IrisRender
@testable import OpenUIKit
import Testing

/// A PNG of `width` × `height` pixels.
private func png(_ width: Float, _ height: Float) -> [UInt8] {
    IrisRender.Scene(width: width, height: height, scale: 1).encode(.png)!
}

@Test func imagesComeFromAssetCatalogsFilesAndData() throws {
    // A bundle as irisrun lays out an app: resources next to the executable.
    let root = FileManager.default.temporaryDirectory.appending(path: "iris-images-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let set = root.appending(path: "Assets.xcassets/Icons/Logo.imageset")
    try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    try Data(#"{"properties": {"provides-namespace": true}}"#.utf8).write(to: set.deletingLastPathComponent().appending(path: "Contents.json"))
    try Data("""
    {"images": [{"idiom": "universal", "scale": "1x"}, {"idiom": "universal", "scale": "2x", "filename": "logo@2x.png"},
                {"idiom": "universal", "scale": "3x", "filename": "logo@3x.png"}],
     "properties": {"template-rendering-intent": "template"}}
    """.utf8).write(to: set.appending(path: "Contents.json"))
    try Data(png(80, 40)).write(to: set.appending(path: "logo@2x.png"))
    try Data(png(120, 60)).write(to: set.appending(path: "logo@3x.png"))
    try Data(png(30, 30)).write(to: root.appending(path: "badge@3x.png"))
    let bundle = try #require(Bundle(path: root.path))

    // The variant for the screen's scale (3 in scripts), and the set's rendering.
    let logo = try #require(UIImage(named: "Icons/Logo", in: bundle, compatibleWith: nil))
    #expect(logo.size == CGSize(width: 40, height: 20) && logo.scale == 3)
    #expect(logo.renderingMode == .alwaysTemplate && logo.withRenderingMode(.alwaysOriginal).renderingMode == .alwaysOriginal)
    #expect(UIImage(named: "Logo", in: bundle, compatibleWith: nil) == nil, "namespaced")
    #expect(UIImage(named: "badge", in: bundle, compatibleWith: nil)?.size == CGSize(width: 10, height: 10))

    let file = try #require(UIImage(contentsOfFile: set.appending(path: "logo@2x.png").path))
    #expect(file.scale == 2 && file.size == CGSize(width: 40, height: 20) && file.renderingMode == .automatic)
    #expect(UIImage(data: Data(png(8, 6)))?.size == CGSize(width: 8, height: 6))
    #expect(UIImage(data: Data(png(8, 6)), scale: 2)?.size == CGSize(width: 4, height: 3))
    #expect(UIImage(data: Data("not an image".utf8)) == nil)

    let symbol = try #require(UIImage(systemName: "star.fill"))
    #expect(symbol.isSymbolImage && symbol.size == CGSize(width: 20, height: 20) && symbol.cgImage == nil)

    let cgImage = try #require(logo.cgImage)
    #expect(UIImage(cgImage: cgImage, scale: 3, orientation: .up).size == logo.size)
}

@Test func layersDrawImageContents() throws {
    let scene = IrisRender.Scene(width: 100, height: 100, scale: 1)
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    #expect(layer.draw(in: scene))
    layer.contents = try #require(UIImage(data: Data(png(10, 10)))?.cgImage)
    layer.contentsGravity = .resizeAspect
    #expect(layer.changes == .contents)
    #expect(layer.draw(in: scene))
    #expect(!layer.draw(in: scene))
}

@MainActor @Test func fontsHaveTheRenderCoresMetrics() throws {
    if irisScene == nil {
        irisScene = .window(size: CGSize(width: 390, height: 844), scale: 3)
    }
    let body = UIFont.preferredFont(forTextStyle: .body)
    #expect(body.pointSize == 17 && body.fontName == ".SFUI-Regular" && body.familyName == ".AppleSystemUIFont")
    #expect(body.ascender > body.capHeight && body.capHeight > body.xHeight && body.xHeight > 0 && body.descender < 0)
    #expect(body.lineHeight == body.ascender - body.descender + body.leading)
    let metrics = try #require(irisScene.fontMetrics(size: 17, weight: 400))
    #expect(body.ascender == CGFloat(metrics.ascender))
    #expect(body.withSize(34).ascender == 2 * body.ascender || abs(body.withSize(34).ascender - 2 * body.ascender) < 0.01)

    let headline = UIFont.preferredFont(forTextStyle: .headline)
    #expect(headline.pointSize == 17 && headline.fontName == ".SFUI-Semibold")
    #expect(headline.fontDescriptor.symbolicTraits.contains(.traitBold))
    #expect(UIFont.preferredFont(forTextStyle: .largeTitle).pointSize == 34)
    #expect(UIFont.preferredFont(forTextStyle: .caption2).pointSize == 11)
    #expect(UIFont.systemFont(ofSize: 15, weight: .medium).fontName == ".SFUI-Medium")
    #expect(UIFont.italicSystemFont(ofSize: 12).fontName == ".SFUI-RegularItalic")
    #expect(UIFont.monospacedSystemFont(ofSize: 12, weight: .bold).fontDescriptor.symbolicTraits == [.traitBold, .traitMonoSpace])
    #expect(UIFont.systemFont(ofSize: 17) == body && UIFont.boldSystemFont(ofSize: 17) != body)

    // Traits replace the descriptor's own, as on iOS.
    let boldBody = UIFont(descriptor: try #require(body.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])), size: 0)
    #expect(boldBody.pointSize == 17 && boldBody.fontName == ".SFUI-BoldItalic")
    #expect(try #require(boldBody.fontDescriptor.withSymbolicTraits([])).symbolicTraits == [])

    // A named font is the system font with the weight its name says.
    let named = try #require(UIFont(name: "Montserrat-SemiBoldItalic", size: 20))
    #expect(named.fontName == "Montserrat-SemiBoldItalic" && named.familyName == "Montserrat")
    #expect(named.fontDescriptor.symbolicTraits == [.traitBold, .traitItalic] && named.withSize(10).fontName == "Montserrat-SemiBoldItalic")
}
