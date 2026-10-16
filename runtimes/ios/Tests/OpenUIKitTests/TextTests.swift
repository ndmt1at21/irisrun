import Foundation
import IrisHost
import IrisRender
@testable import OpenUIKit
import Testing

// Attributed text as the render core takes it, string measuring, and labels.

/// The window's scene, which text measures with.
func makeScene() {
    if irisScene == nil {
        irisScene = .window(size: CGSize(width: 390, height: 844), scale: 3)
    }
}

@Test func attributedTextBecomesRenderCoreRuns() {
    makeScene()
    // "Xin chào 👋 " is 12 UTF-16 units and 15 UTF-8 bytes.
    let text = NSMutableAttributedString(string: "Xin chào 👋 bold", attributes: [.kern: 1.5])
    let bold = UIFont.boldSystemFont(ofSize: 20)
    text._irisAddAttributes([.font: bold, .foregroundColor: UIColor.systemRed, .underlineStyle: NSUnderlineStyle.single.rawValue], range: NSRange(location: 12, length: 4))
    text._irisAddAttribute(.link, value: "https://irisrun.dev", range: NSRange(location: 0, length: 3))
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = 2
    style.lineHeightMultiple = 1.5
    text._irisAddAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))

    let iris = IrisText(text, font: .systemFont(ofSize: 17), color: .label)
    #expect(iris.runs.map(\.range) == [0 ..< 3, 3 ..< 15, 15 ..< 19])
    #expect(iris.runs[0].color == UIColor.link.cgColor.argb && iris.runs[0].isUnderlined, "links show as links")
    #expect(iris.runs[1].size == 17 && iris.runs[1].weight == 400 && iris.runs[1].letterSpacing == 1.5 && !iris.runs[1].isUnderlined)
    #expect(iris.runs[2].size == 20 && iris.runs[2].weight == 700 && iris.runs[2].isUnderlined && iris.runs[2].color == UIColor.systemRed.cgColor.argb)
    #expect(iris.paragraph.alignment == .center)
    // The extra half line of 17-point text goes between lines, with the spacing.
    let lineHeight = UIFont.systemFont(ofSize: 17).lineHeight
    #expect(abs(CGFloat(iris.paragraph.lineSpacing) - (2 + lineHeight / 2)) < 0.01)

    // Copies of paragraph styles are their own, and mutable ones are mutable.
    let copy = style.mutableCopy() as! NSMutableParagraphStyle
    copy.alignment = .right
    #expect(style.alignment == .center && (style.copy() as! NSParagraphStyle).lineSpacing == 2)
}

@Test func stringsMeasureAsTheyDraw() {
    makeScene()
    let font = UIFont.systemFont(ofSize: 17)
    let metrics = irisScene.measure("Hello, Iris", runs: [TextRun(0 ..< 11, size: 17)])
    #expect("Hello, Iris".size(withAttributes: [.font: font]) == CGSize(width: CGFloat(metrics.width), height: CGFloat(metrics.height)))
    #expect(("Hello, Iris" as NSString).size(withAttributes: [.font: font]).width == CGFloat(metrics.width))
    #expect("Hello".size(withAttributes: nil).height < "Hello".size(withAttributes: [.font: font]).height, "12 points without a font")

    let long = "A sentence long enough to wrap in a narrow column of text"
    let wrapped = long.boundingRect(with: CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
    let line = long.boundingRect(with: CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude), options: [], attributes: [.font: font], context: nil)
    #expect(wrapped.width <= 120 && wrapped.height > 3 * line.height && line.width > 120)
    #expect(NSAttributedString(string: long, attributes: [.font: font]).size() == line.size)
}

@MainActor @Test func labelsSizeTruncateAndCenterTheirText() throws {
    makeScene()
    let label = UILabel()
    #expect(label.intrinsicContentSize == .zero && label.font.pointSize == 17 && label.textColor == .label)
    label.text = "Hello, Iris"
    let size = "Hello, Iris".size(withAttributes: [.font: label.font!])
    #expect(label.intrinsicContentSize == CGSize(width: ceil(size.width), height: ceil(size.height)))
    #expect(label.accessibilityLabel == "Hello, Iris")

    // Wrapping: sizeThatFits wraps multi-line labels at the width, and the intrinsic size at
    // preferredMaxLayoutWidth.
    label.text = "A sentence long enough to wrap in a narrow column of text"
    label.numberOfLines = 0
    let fits = label.sizeThatFits(CGSize(width: 120, height: 1000))
    #expect(fits.width <= 120 && fits.height > 3 * size.height)
    label.preferredMaxLayoutWidth = 120
    #expect(label.intrinsicContentSize == fits)
    label.numberOfLines = 2
    #expect(label.sizeThatFits(CGSize(width: 120, height: 1000)).height < fits.height)

    // Drawing: as many lines as fit in the bounds, the text centered vertically in them.
    label.frame = CGRect(x: 0, y: 0, width: 120, height: 50)
    label.numberOfLines = 0
    let (_, shown) = try #require(label.fittedText(in: label.bounds.size))
    #expect(CGFloat(shown.height) <= 50 && shown.isTruncated && shown.lineCount == 2)
    label.drawText(in: label.bounds)
    let drawing = try #require(label.layer.irisDrawing)
    #expect(drawing.frame.width == 120 && abs(drawing.frame.midY - 25) < 0.01)
    label.drawText(in: label.bounds.insetBy(dx: 10, dy: 0))
    #expect(label.layer.irisDrawing?.frame.minX == 10)

    // One line cuts the text; shrinking to fit makes it smaller instead, down to the factor.
    label.numberOfLines = 1
    label.frame.size.height = 30
    #expect(try #require(label.fittedText(in: label.bounds.size)).1.isTruncated)
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.2
    let (shrunk, metrics) = try #require(label.fittedText(in: label.bounds.size))
    #expect(!metrics.isTruncated && shrunk.runs[0].size < 17 && shrunk.runs[0].size >= 17 * 0.2)
    label.minimumScaleFactor = 0.9
    #expect(try #require(label.fittedText(in: label.bounds.size)).1.isTruncated, "not that small")
}

@MainActor @Test func labelsApplyTheirAttributesToAttributedText() throws {
    makeScene()
    let label = UILabel()
    label.attributedText = NSAttributedString(string: "Bold", attributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
    #expect(label.text == "Bold")
    var range = NSRange(location: 0, length: 0)
    let attributes = try #require(label.attributedText?.attributes(at: 0, effectiveRange: &range))
    #expect((attributes[.font] as? UIFont)?.pointSize == 20 && attributes[.foregroundColor] as? UIColor == .label)
    // A font, color or alignment set afterwards applies to all of it.
    label.textColor = .systemBlue
    label.font = .systemFont(ofSize: 12)
    label.textAlignment = .right
    let text = try #require(label.attributedText)
    #expect((text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize == 12)
    #expect(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemBlue)
    #expect((text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment == .right)
    // Highlighted and disabled labels recolor the text.
    label.frame = CGRect(x: 0, y: 0, width: 200, height: 30)
    label.highlightedTextColor = .white
    label.isHighlighted = true
    #expect(try #require(label.fittedText(in: label.bounds.size)).0.runs[0].color == UIColor.white.cgColor.argb)
    label.isEnabled = false
    #expect(try #require(label.fittedText(in: label.bounds.size)).0.runs[0].color == UIColor.systemGray.cgColor.argb)
}
