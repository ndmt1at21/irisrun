import Foundation
import IrisHost
import IrisRender

// UIKit's text attributes and paragraph styles, the string measuring of NSStringDrawing, and
// `IrisText`: attributed text as the render core lays it out, so that what UIKit measures is
// what it draws. Foundation on Linux has NSAttributedString but none of UIKit's attributes.

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key("NSFont")
    public static let paragraphStyle = NSAttributedString.Key("NSParagraphStyle")
    public static let foregroundColor = NSAttributedString.Key("NSColor")
    public static let backgroundColor = NSAttributedString.Key("NSBackgroundColor")
    public static let ligature = NSAttributedString.Key("NSLigature")
    public static let kern = NSAttributedString.Key("NSKern")
    public static let tracking = NSAttributedString.Key("NSTracking")
    public static let strikethroughStyle = NSAttributedString.Key("NSStrikethrough")
    public static let underlineStyle = NSAttributedString.Key("NSUnderline")
    public static let strokeColor = NSAttributedString.Key("NSStrokeColor")
    public static let strokeWidth = NSAttributedString.Key("NSStrokeWidth")
    public static let shadow = NSAttributedString.Key("NSShadow")
    public static let textEffect = NSAttributedString.Key("NSTextEffect")
    public static let attachment = NSAttributedString.Key("NSAttachment")
    public static let link = NSAttributedString.Key("NSLink")
    public static let baselineOffset = NSAttributedString.Key("NSBaselineOffset")
    public static let underlineColor = NSAttributedString.Key("NSUnderlineColor")
    public static let strikethroughColor = NSAttributedString.Key("NSStrikethroughColor")
    public static let obliqueness = NSAttributedString.Key("NSObliqueness")
    public static let expansion = NSAttributedString.Key("NSExpansion")
    public static let writingDirection = NSAttributedString.Key("NSWritingDirection")
    public static let verticalGlyphForm = NSAttributedString.Key("NSVerticalGlyphForm")
}

/// iOS's raw values, which differ from macOS's.
public enum NSTextAlignment: Int, Sendable {
    case left = 0, center = 1, right = 2, justified = 3, natural = 4
}

public enum NSLineBreakMode: Int, Sendable {
    case byWordWrapping = 0, byCharWrapping, byClipping, byTruncatingHead, byTruncatingTail, byTruncatingMiddle
}

public enum NSWritingDirection: Int, Sendable {
    case natural = -1, leftToRight = 0, rightToLeft = 1
}

public struct NSUnderlineStyle: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let single = NSUnderlineStyle(rawValue: 0x01)
    public static let thick = NSUnderlineStyle(rawValue: 0x02)
    public static let double = NSUnderlineStyle(rawValue: 0x09)
    public static let patternDot = NSUnderlineStyle(rawValue: 0x0100)
    public static let patternDash = NSUnderlineStyle(rawValue: 0x0200)
    public static let patternDashDot = NSUnderlineStyle(rawValue: 0x0300)
    public static let patternDashDotDot = NSUnderlineStyle(rawValue: 0x0400)
    public static let byWord = NSUnderlineStyle(rawValue: 0x8000)
}

/// How a paragraph lays out. Text views read the first paragraph's style for all their text.
open class NSParagraphStyle: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    open class var `default`: NSParagraphStyle {
        NSParagraphStyle()
    }

    open class func defaultWritingDirection(forLanguage languageName: String?) -> NSWritingDirection {
        .leftToRight
    }

    open fileprivate(set) var lineSpacing: CGFloat = 0
    open fileprivate(set) var paragraphSpacing: CGFloat = 0
    open fileprivate(set) var alignment = NSTextAlignment.natural
    open fileprivate(set) var headIndent: CGFloat = 0
    open fileprivate(set) var tailIndent: CGFloat = 0
    open fileprivate(set) var firstLineHeadIndent: CGFloat = 0
    open fileprivate(set) var minimumLineHeight: CGFloat = 0
    open fileprivate(set) var maximumLineHeight: CGFloat = 0
    open fileprivate(set) var lineBreakMode = NSLineBreakMode.byWordWrapping
    open fileprivate(set) var baseWritingDirection = NSWritingDirection.natural
    open fileprivate(set) var lineHeightMultiple: CGFloat = 0
    open fileprivate(set) var paragraphSpacingBefore: CGFloat = 0
    open fileprivate(set) var hyphenationFactor: Float = 0
    open fileprivate(set) var allowsDefaultTighteningForTruncation = false

    public override init() {
        super.init()
    }

    open func copy(with zone: NSZone? = nil) -> Any {
        NSParagraphStyle(copying: self)
    }

    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        NSMutableParagraphStyle(copying: self)
    }

    fileprivate convenience init(copying style: NSParagraphStyle) {
        self.init()
        (lineSpacing, paragraphSpacing, alignment, headIndent) = (style.lineSpacing, style.paragraphSpacing, style.alignment, style.headIndent)
        (tailIndent, firstLineHeadIndent, minimumLineHeight) = (style.tailIndent, style.firstLineHeadIndent, style.minimumLineHeight)
        (maximumLineHeight, lineBreakMode, baseWritingDirection) = (style.maximumLineHeight, style.lineBreakMode, style.baseWritingDirection)
        (lineHeightMultiple, paragraphSpacingBefore) = (style.lineHeightMultiple, style.paragraphSpacingBefore)
        (hyphenationFactor, allowsDefaultTighteningForTruncation) = (style.hyphenationFactor, style.allowsDefaultTighteningForTruncation)
    }
}

open class NSMutableParagraphStyle: NSParagraphStyle, @unchecked Sendable {
    open override var lineSpacing: CGFloat { get { super.lineSpacing } set { super.lineSpacing = newValue } }
    open override var paragraphSpacing: CGFloat { get { super.paragraphSpacing } set { super.paragraphSpacing = newValue } }
    open override var alignment: NSTextAlignment { get { super.alignment } set { super.alignment = newValue } }
    open override var headIndent: CGFloat { get { super.headIndent } set { super.headIndent = newValue } }
    open override var tailIndent: CGFloat { get { super.tailIndent } set { super.tailIndent = newValue } }
    open override var firstLineHeadIndent: CGFloat { get { super.firstLineHeadIndent } set { super.firstLineHeadIndent = newValue } }
    open override var minimumLineHeight: CGFloat { get { super.minimumLineHeight } set { super.minimumLineHeight = newValue } }
    open override var maximumLineHeight: CGFloat { get { super.maximumLineHeight } set { super.maximumLineHeight = newValue } }
    open override var lineBreakMode: NSLineBreakMode { get { super.lineBreakMode } set { super.lineBreakMode = newValue } }
    open override var baseWritingDirection: NSWritingDirection { get { super.baseWritingDirection } set { super.baseWritingDirection = newValue } }
    open override var lineHeightMultiple: CGFloat { get { super.lineHeightMultiple } set { super.lineHeightMultiple = newValue } }
    open override var paragraphSpacingBefore: CGFloat { get { super.paragraphSpacingBefore } set { super.paragraphSpacingBefore = newValue } }
    open override var hyphenationFactor: Float { get { super.hyphenationFactor } set { super.hyphenationFactor = newValue } }
    open override var allowsDefaultTighteningForTruncation: Bool {
        get { super.allowsDefaultTighteningForTruncation }
        set { super.allowsDefaultTighteningForTruncation = newValue }
    }

    open func setParagraphStyle(_ obj: NSParagraphStyle) {
        let copy = NSParagraphStyle(copying: obj)
        (lineSpacing, paragraphSpacing, alignment, headIndent) = (copy.lineSpacing, copy.paragraphSpacing, copy.alignment, copy.headIndent)
        (tailIndent, firstLineHeadIndent, minimumLineHeight) = (copy.tailIndent, copy.firstLineHeadIndent, copy.minimumLineHeight)
        (maximumLineHeight, lineBreakMode, baseWritingDirection) = (copy.maximumLineHeight, copy.lineBreakMode, copy.baseWritingDirection)
        (lineHeightMultiple, paragraphSpacingBefore) = (copy.lineHeightMultiple, copy.paragraphSpacingBefore)
        (hyphenationFactor, allowsDefaultTighteningForTruncation) = (copy.hyphenationFactor, copy.allowsDefaultTighteningForTruncation)
    }
}

// MARK: Measuring

public struct NSStringDrawingOptions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let usesLineFragmentOrigin = NSStringDrawingOptions(rawValue: 1 << 0)
    public static let usesFontLeading = NSStringDrawingOptions(rawValue: 1 << 1)
    public static let usesDeviceMetrics = NSStringDrawingOptions(rawValue: 1 << 3)
    public static let truncatesLastVisibleLine = NSStringDrawingOptions(rawValue: 1 << 5)
}

open class NSStringDrawingContext: NSObject {
    open var minimumScaleFactor: CGFloat = 0
    open private(set) var actualScaleFactor: CGFloat = 1
    open private(set) var totalBounds = CGRect.zero
}

extension NSAttributedString {
    /// The size of the text on one line, or lines split at its line breaks.
    public func size() -> CGSize {
        let metrics = IrisText(self, font: .defaultForDrawing, color: .black).measure(maxWidth: .infinity)
        return CGSize(width: CGFloat(metrics.width), height: CGFloat(metrics.height))
    }

    /// The bounds of the text in lines up to `size.width` wide with `.usesLineFragmentOrigin`,
    /// or on one line without it.
    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], context: NSStringDrawingContext?) -> CGRect {
        let width = options.contains(.usesLineFragmentOrigin) ? size.width : .infinity
        let metrics = IrisText(self, font: .defaultForDrawing, color: .black).measure(maxWidth: width)
        return CGRect(x: 0, y: 0, width: CGFloat(metrics.width), height: CGFloat(metrics.height))
    }
}

extension NSString {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> CGSize {
        NSAttributedString(string: String(self), attributes: attrs).size()
    }

    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) -> CGRect {
        NSAttributedString(string: String(self), attributes: attributes).boundingRect(with: size, options: options, context: context)
    }
}

/// On iOS a String has NSString's methods; Linux doesn't bridge them.
extension String {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> CGSize {
        NSAttributedString(string: self, attributes: attrs).size()
    }

    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) -> CGRect {
        NSAttributedString(string: self, attributes: attributes).boundingRect(with: size, options: options, context: context)
    }
}

extension UIFont {
    /// What strings without a font are drawn in: Helvetica 12 on iOS.
    static var defaultForDrawing: UIFont {
        .systemFont(ofSize: 12)
    }
}

// MARK: The render core's text

/// Iris: attributed text as the render core lays it out: runs of styles over UTF-8 bytes, and
/// one paragraph style.
// ponytail: the first paragraph's style is everyone's; paragraph spacing, indents, justified
// text, strokes, shadows and attachments don't show; line heights become spacing between lines.
struct IrisText {
    var string: String
    var runs: [TextRun]
    var paragraph: ParagraphStyle

    /// `text` with `font` and `color` where it has none, aligned by its paragraph style or by
    /// `alignment`. Links show in the link color, underlined, as in a label.
    init(_ text: NSAttributedString, font: UIFont, color: UIColor, alignment: NSTextAlignment = .natural) {
        let string = text.string
        self.string = string
        let utf16 = string.utf16
        func utf8Offset(_ utf16Offset: Int) -> Int {
            let index = utf16.index(utf16.startIndex, offsetBy: min(max(utf16Offset, 0), utf16.count))
            return string.utf8.distance(from: string.utf8.startIndex, to: index)
        }
        var runs: [TextRun] = []
        var style: NSParagraphStyle?
        var firstFont: UIFont?
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
            let runFont = attributes[.font] as? UIFont ?? font
            let isLink = attributes[.link] != nil
            let runColor = isLink ? UIColor.link : attributes[.foregroundColor] as? UIColor ?? color
            runs.append(TextRun(
                utf8Offset(range.location) ..< utf8Offset(range.location + range.length),
                size: Float(runFont.pointSize), weight: runFont.weight.cssWeight, color: runColor.cgColor.argb,
                isItalic: runFont.isItalic, isUnderlined: isLink || Self.isLined(attributes[.underlineStyle]),
                isStruckThrough: Self.isLined(attributes[.strikethroughStyle]),
                letterSpacing: Self.number(attributes[.kern] ?? attributes[.tracking]),
                baselineOffset: Self.number(attributes[.baselineOffset]),
                backgroundColor: (attributes[.backgroundColor] as? UIColor)?.cgColor.argb ?? 0
            ))
            style = style ?? attributes[.paragraphStyle] as? NSParagraphStyle
            firstFont = firstFont ?? runFont
        }
        self.runs = runs
        var spacing = style?.lineSpacing ?? 0
        if let style, style.lineHeightMultiple > 0 || style.minimumLineHeight > 0 || style.maximumLineHeight > 0 {
            // UIKit sets each line's height; the render core adds the difference between lines.
            let natural = (firstFont ?? font).lineHeight
            var height = max(natural * (style.lineHeightMultiple > 0 ? style.lineHeightMultiple : 1), style.minimumLineHeight)
            if style.maximumLineHeight > 0 {
                height = min(height, style.maximumLineHeight)
            }
            spacing += height - natural
        }
        let textAlignment: TextAlignment = switch style?.alignment ?? alignment {
        case .center: .center
        case .right: .trailing
        default: .leading
        }
        paragraph = ParagraphStyle(alignment: textAlignment, lineSpacing: Float(spacing))
    }

    /// An underline or strikethrough style: NSUnderlineStyle or its raw value.
    private static func isLined(_ value: Any?) -> Bool {
        if let style = value as? NSUnderlineStyle { return !style.isEmpty }
        return Int(number(value)) != 0
    }

    private static func number(_ value: Any?) -> Float {
        switch value {
        case let value as CGFloat: Float(value)
        case let value as Double: Float(value)
        case let value as Float: value
        case let value as Int: Float(value)
        case let value as NSNumber: value.floatValue
        default: 0
        }
    }

    /// Lays the text out in lines up to `maxWidth` wide, at most `maxLines` of them (0 for any
    /// number), the last one cut with "…".
    func measure(maxWidth: CGFloat, maxLines: Int = 0) -> TextMetrics {
        var paragraph = paragraph
        paragraph.maxLines = UInt32(max(maxLines, 0))
        return irisScene.measure(string, runs: runs, paragraph: paragraph, maxWidth: maxWidth < 1e9 ? Float(maxWidth) : .infinity)
    }

    /// The same text with every size scaled, as a label shrinks text to fit.
    func scaled(by scale: CGFloat) -> IrisText {
        var text = self
        for index in text.runs.indices {
            text.runs[index].size *= Float(scale)
            text.runs[index].letterSpacing *= Float(scale)
        }
        return text
    }

    /// The same text in one color.
    func colored(_ color: UIColor) -> IrisText {
        var text = self
        for index in text.runs.indices {
            text.runs[index].color = color.cgColor.argb
        }
        return text
    }
}

// MARK: AttributedString

extension AttributeScopes {
    /// UIKit's attributes for AttributedString, as `AttributeContainer().font = UIFont…` sets
    /// them in a button configuration's title.
    public struct UIKitAttributes: AttributeScope {
        public let font: FontAttribute
        public let foregroundColor: ForegroundColorAttribute
        public let backgroundColor: BackgroundColorAttribute
        public let paragraphStyle: ParagraphStyleAttribute
        public let kern: KernAttribute
        public let tracking: TrackingAttribute
        public let underlineStyle: UnderlineStyleAttribute
        public let strikethroughStyle: StrikethroughStyleAttribute
        public let baselineOffset: BaselineOffsetAttribute
        public let foundation: AttributeScopes.FoundationAttributes

        public enum FontAttribute: AttributedStringKey {
            public typealias Value = UIFont
            public static let name = NSAttributedString.Key.font.rawValue
        }

        public enum ForegroundColorAttribute: AttributedStringKey {
            public typealias Value = UIColor
            public static let name = NSAttributedString.Key.foregroundColor.rawValue
        }

        public enum BackgroundColorAttribute: AttributedStringKey {
            public typealias Value = UIColor
            public static let name = NSAttributedString.Key.backgroundColor.rawValue
        }

        public enum ParagraphStyleAttribute: AttributedStringKey {
            public typealias Value = NSParagraphStyle
            public static let name = NSAttributedString.Key.paragraphStyle.rawValue
        }

        public enum KernAttribute: AttributedStringKey {
            public typealias Value = CGFloat
            public static let name = NSAttributedString.Key.kern.rawValue
        }

        public enum TrackingAttribute: AttributedStringKey {
            public typealias Value = CGFloat
            public static let name = NSAttributedString.Key.tracking.rawValue
        }

        public enum UnderlineStyleAttribute: AttributedStringKey {
            public typealias Value = NSUnderlineStyle
            public static let name = NSAttributedString.Key.underlineStyle.rawValue
        }

        public enum StrikethroughStyleAttribute: AttributedStringKey {
            public typealias Value = NSUnderlineStyle
            public static let name = NSAttributedString.Key.strikethroughStyle.rawValue
        }

        public enum BaselineOffsetAttribute: AttributedStringKey {
            public typealias Value = CGFloat
            public static let name = NSAttributedString.Key.baselineOffset.rawValue
        }
    }

    public var uiKit: UIKitAttributes.Type {
        UIKitAttributes.self
    }
}

extension AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.UIKitAttributes, T>) -> T {
        self[T.self]
    }
}

extension AttributeContainer {
    /// The UIKit attributes of a dictionary, as on iOS; others are dropped.
    public init(_ dictionary: [NSAttributedString.Key: Any]) {
        self.init()
        self.uiKit.font = dictionary[.font] as? UIFont
        self.uiKit.foregroundColor = dictionary[.foregroundColor] as? UIColor
        self.uiKit.backgroundColor = dictionary[.backgroundColor] as? UIColor
        self.uiKit.paragraphStyle = dictionary[.paragraphStyle] as? NSParagraphStyle
        self.uiKit.kern = dictionary[.kern] as? CGFloat
        self.uiKit.baselineOffset = dictionary[.baselineOffset] as? CGFloat
    }

    /// Iris: the container's UIKit attributes as NSAttributedString's.
    var irisAttributes: [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        attributes[.font] = self.uiKit.font
        attributes[.foregroundColor] = self.uiKit.foregroundColor
        attributes[.backgroundColor] = self.uiKit.backgroundColor
        attributes[.paragraphStyle] = self.uiKit.paragraphStyle
        attributes[.kern] = self.uiKit.kern
        attributes[.tracking] = self.uiKit.tracking
        attributes[.underlineStyle] = self.uiKit.underlineStyle?.rawValue
        attributes[.strikethroughStyle] = self.uiKit.strikethroughStyle?.rawValue
        attributes[.baselineOffset] = self.uiKit.baselineOffset
        attributes[.link] = self.link
        return attributes
    }
}

extension AttributedString {
    /// Iris: the string as NSAttributedString, with its UIKit attributes; Foundation on Linux
    /// has no conversion.
    var irisNSAttributedString: NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for run in runs {
            result.append(NSAttributedString(string: String(characters[run.range]), attributes: run.attributes.irisAttributes))
        }
        return result
    }
}
