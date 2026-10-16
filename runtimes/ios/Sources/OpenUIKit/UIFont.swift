import Foundation
import IrisHost

/// A font: the system font at a size, weight and style. Iris draws all text with the render
/// core's fonts (Inter, with Noto Sans SC for CJK), so metrics come from them, once the app
/// runs (`irisScene`).
// ponytail: named fonts take the system font with the weight and style their name says, and
// monospaced fonts are Inter too; the app's own fonts (UIAppFonts) come with text (step 2).
open class UIFont: NSObject, @unchecked Sendable {
    open private(set) var pointSize: CGFloat
    open private(set) var fontName: String
    open private(set) var familyName: String
    let weight: Weight
    let isItalic: Bool
    let isMonospaced: Bool

    init(size: CGFloat, weight: Weight, italic: Bool = false, monospaced: Bool = false, name: String? = nil) {
        pointSize = size
        self.weight = weight
        isItalic = italic
        isMonospaced = monospaced
        fontName = name ?? (monospaced ? ".SFUIMono-" : ".SFUI-") + weight.name + (italic ? "Italic" : "")
        familyName = name.map { String($0.prefix { $0 != "-" }) } ?? (monospaced ? ".AppleSystemUIFontMonospaced" : ".AppleSystemUIFont")
        super.init()
    }

    open class func systemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont(size: fontSize, weight: .regular)
    }

    open class func systemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont(size: fontSize, weight: weight)
    }

    open class func boldSystemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont(size: fontSize, weight: .bold)
    }

    open class func italicSystemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont(size: fontSize, weight: .regular, italic: true)
    }

    /// ponytail: digits are Inter's proportional ones until the render core takes font features.
    open class func monospacedDigitSystemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont(size: fontSize, weight: weight)
    }

    open class func monospacedSystemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont(size: fontSize, weight: weight, monospaced: true)
    }

    /// The font of a text style at iOS's default text size (Large).
    open class func preferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let (size, weight) = style.defaultFont
        return UIFont(size: size, weight: weight)
    }

    open class func preferredFont(forTextStyle style: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection?) -> UIFont {
        preferredFont(forTextStyle: style)
    }

    /// Any name gives a font, so that apps unwrapping fonts they bundle keep running.
    public convenience init?(name fontName: String, size fontSize: CGFloat) {
        let style = fontName.split(separator: "-").last.map { $0.lowercased() } ?? ""
        let weight = Weight.byName.first { style.hasPrefix($0.key) }?.value ?? .regular
        self.init(size: fontSize, weight: weight, italic: style.contains("italic") || style.contains("oblique"), name: fontName)
    }

    /// A size of 0 keeps the descriptor's.
    public convenience init(descriptor: UIFontDescriptor, size pointSize: CGFloat) {
        let font = descriptor.font
        self.init(size: pointSize > 0 ? pointSize : font.pointSize, weight: font.weight, italic: font.isItalic, monospaced: font.isMonospaced, name: font.fontName.hasPrefix(".") ? nil : font.fontName)
    }

    open func withSize(_ fontSize: CGFloat) -> UIFont {
        UIFont(size: fontSize, weight: weight, italic: isItalic, monospaced: isMonospaced, name: fontName.hasPrefix(".") ? nil : fontName)
    }

    open var fontDescriptor: UIFontDescriptor {
        UIFontDescriptor(self)
    }

    // MARK: Metrics

    private lazy var metrics: FontMetricsInPoints = {
        guard let scene = irisScene, let metrics = scene.fontMetrics(size: Float(pointSize), weight: weight.cssWeight) else {
            fatalError("irisrun: UIFont measures with the window's fonts, which load when the app starts")
        }
        return FontMetricsInPoints(
            ascender: CGFloat(metrics.ascender), descender: CGFloat(metrics.descender), leading: CGFloat(metrics.leading),
            capHeight: CGFloat(metrics.capHeight), xHeight: CGFloat(metrics.xHeight)
        )
    }()

    private struct FontMetricsInPoints {
        var ascender, descender, leading, capHeight, xHeight: CGFloat
    }

    open var ascender: CGFloat { metrics.ascender }
    /// Negative: below the baseline.
    open var descender: CGFloat { metrics.descender }
    open var leading: CGFloat { metrics.leading }
    open var capHeight: CGFloat { metrics.capHeight }
    open var xHeight: CGFloat { metrics.xHeight }

    /// From one baseline to the next.
    open var lineHeight: CGFloat {
        metrics.ascender - metrics.descender + metrics.leading
    }

    // MARK: Equality

    /// Fonts of the same name and size are equal, as UIKit's are.
    override open func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UIFont else { return false }
        return fontName == other.fontName && pointSize == other.pointSize
    }

    override open var hash: Int {
        fontName.hashValue ^ pointSize.hashValue
    }
}

extension UIFont {
    public struct Weight: RawRepresentable, Hashable, Sendable {
        public let rawValue: CGFloat

        public init(rawValue: CGFloat) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: CGFloat) {
            self.rawValue = rawValue
        }

        public static let ultraLight = Weight(-0.8)
        public static let thin = Weight(-0.6)
        public static let light = Weight(-0.4)
        public static let regular = Weight(0)
        public static let medium = Weight(0.23)
        public static let semibold = Weight(0.3)
        public static let bold = Weight(0.4)
        public static let heavy = Weight(0.56)
        public static let black = Weight(0.62)

        /// The weights in order, with the name their fonts have and their CSS weight.
        private static let named: [(weight: Weight, name: String, css: UInt16)] = [
            (.ultraLight, "Ultralight", 100), (.thin, "Thin", 200), (.light, "Light", 300),
            (.regular, "Regular", 400), (.medium, "Medium", 500), (.semibold, "Semibold", 600),
            (.bold, "Bold", 700), (.heavy, "Heavy", 800), (.black, "Black", 900),
        ]

        /// The named weight closest to this one.
        private var nearest: (weight: Weight, name: String, css: UInt16) {
            Self.named.min { abs($0.weight.rawValue - rawValue) < abs($1.weight.rawValue - rawValue) }!
        }

        var name: String { nearest.name }

        /// 100 to 900, as the render core takes weights.
        var cssWeight: UInt16 { nearest.css }

        /// Weights by the word that starts the style in a font's name, lowercased:
        /// "Montserrat-SemiBoldItalic" is semibold.
        static let byName: KeyValuePairs<String, Weight> = [
            "ultralight": .ultraLight, "extralight": .ultraLight, "semibold": .semibold, "demibold": .semibold,
            "extrabold": .heavy, "thin": .thin, "light": .light, "regular": .regular, "medium": .medium,
            "bold": .bold, "heavy": .heavy, "black": .black,
        ]
    }

    public struct TextStyle: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public static let largeTitle = TextStyle("UICTFontTextStyleTitle0")
        public static let title1 = TextStyle("UICTFontTextStyleTitle1")
        public static let title2 = TextStyle("UICTFontTextStyleTitle2")
        public static let title3 = TextStyle("UICTFontTextStyleTitle3")
        public static let headline = TextStyle("UICTFontTextStyleHeadline")
        public static let subheadline = TextStyle("UICTFontTextStyleSubhead")
        public static let body = TextStyle("UICTFontTextStyleBody")
        public static let callout = TextStyle("UICTFontTextStyleCallout")
        public static let footnote = TextStyle("UICTFontTextStyleFootnote")
        public static let caption1 = TextStyle("UICTFontTextStyleCaption1")
        public static let caption2 = TextStyle("UICTFontTextStyleCaption2")

        /// Size and weight at iOS's default text size (Large).
        var defaultFont: (CGFloat, Weight) {
            switch self {
            case .largeTitle: (34, .regular)
            case .title1: (28, .regular)
            case .title2: (22, .regular)
            case .title3: (20, .regular)
            case .headline: (17, .semibold)
            case .callout: (16, .regular)
            case .subheadline: (15, .regular)
            case .footnote: (13, .regular)
            case .caption1: (12, .regular)
            case .caption2: (11, .regular)
            default: (17, .regular)
            }
        }
    }
}

/// What a font is: its name, size and traits.
// ponytail: no font attributes, features or matching; enough for traits and sizes.
open class UIFontDescriptor: NSObject, @unchecked Sendable {
    let font: UIFont

    init(_ font: UIFont) {
        self.font = font
        super.init()
    }

    open class func preferredFontDescriptor(withTextStyle style: UIFont.TextStyle) -> UIFontDescriptor {
        UIFont.preferredFont(forTextStyle: style).fontDescriptor
    }

    open var pointSize: CGFloat {
        font.pointSize
    }

    open var postscriptName: String {
        font.fontName
    }

    open var symbolicTraits: SymbolicTraits {
        var traits = SymbolicTraits()
        if font.weight.rawValue >= UIFont.Weight.semibold.rawValue { traits.insert(.traitBold) }
        if font.isItalic { traits.insert(.traitItalic) }
        if font.isMonospaced { traits.insert(.traitMonoSpace) }
        return traits
    }

    /// The same font with these traits instead of its own.
    open func withSymbolicTraits(_ symbolicTraits: SymbolicTraits) -> UIFontDescriptor? {
        let bold = symbolicTraits.contains(.traitBold)
        let isBold = font.weight.rawValue >= UIFont.Weight.semibold.rawValue
        let weight: UIFont.Weight = bold ? (isBold ? font.weight : .bold) : (isBold ? .regular : font.weight)
        let name = font.fontName.hasPrefix(".") ? nil : font.fontName
        return UIFontDescriptor(UIFont(
            size: font.pointSize, weight: weight, italic: symbolicTraits.contains(.traitItalic),
            monospaced: symbolicTraits.contains(.traitMonoSpace), name: name
        ))
    }

    open func withSize(_ newPointSize: CGFloat) -> UIFontDescriptor {
        UIFontDescriptor(font.withSize(newPointSize))
    }
}

extension UIFontDescriptor {
    public struct SymbolicTraits: OptionSet, Hashable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let traitItalic = SymbolicTraits(rawValue: 1 << 0)
        public static let traitBold = SymbolicTraits(rawValue: 1 << 1)
        public static let traitExpanded = SymbolicTraits(rawValue: 1 << 5)
        public static let traitCondensed = SymbolicTraits(rawValue: 1 << 6)
        public static let traitMonoSpace = SymbolicTraits(rawValue: 1 << 10)
        public static let traitVertical = SymbolicTraits(rawValue: 1 << 11)
        public static let traitUIOptimized = SymbolicTraits(rawValue: 1 << 12)
        public static let traitTightLeading = SymbolicTraits(rawValue: 1 << 15)
        public static let traitLooseLeading = SymbolicTraits(rawValue: 1 << 16)
    }
}
