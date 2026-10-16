import Foundation

/// Colors in sRGB or gray. System colors have their iOS 18 light-mode values.
// ponytail: no dark mode, dynamic providers or named asset colors yet (UITraitCollection, 1b).
open class UIColor: NSObject, @unchecked Sendable {
    private let color: CGColor

    public init(cgColor: CGColor) {
        color = cgColor
    }

    public convenience init(white: CGFloat, alpha: CGFloat) {
        self.init(cgColor: CGColor(gray: white, alpha: alpha))
    }

    public convenience init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(cgColor: CGColor(red: red, green: green, blue: blue, alpha: alpha))
    }

    // ponytail: Display P3 components are taken as sRGB.
    public convenience init(displayP3Red red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public convenience init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        let sector = (hue - hue.rounded(.down)) * 6
        let fraction = sector - sector.rounded(.down)
        let (v, s) = (brightness, saturation)
        let (p, q, t) = (v * (1 - s), v * (1 - s * fraction), v * (1 - s * (1 - fraction)))
        let (red, green, blue): (CGFloat, CGFloat, CGFloat) = switch Int(sector) {
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        default: (v, p, q)
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    open var cgColor: CGColor { color }

    open func withAlphaComponent(_ alpha: CGFloat) -> UIColor {
        UIColor(cgColor: color.copy(alpha: alpha)!)
    }

    open func getRed(
        _ red: UnsafeMutablePointer<CGFloat>?, green: UnsafeMutablePointer<CGFloat>?,
        blue: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?
    ) -> Bool {
        let (r, g, b, a) = color.rgba
        red?.pointee = r
        green?.pointee = g
        blue?.pointee = b
        alpha?.pointee = a
        return true
    }

    /// False for a color that is not gray, as on iOS.
    open func getWhite(_ white: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) -> Bool {
        guard color.numberOfComponents == 2 else { return false }
        white?.pointee = color.components![0]
        alpha?.pointee = color.alpha
        return true
    }

    open func getHue(
        _ hue: UnsafeMutablePointer<CGFloat>?, saturation: UnsafeMutablePointer<CGFloat>?,
        brightness: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?
    ) -> Bool {
        let (r, g, b, a) = color.rgba
        let (high, low) = (max(r, g, b), min(r, g, b))
        let range = high - low
        var h: CGFloat = 0
        if range > 0 {
            h = high == r ? (g - b) / range : high == g ? 2 + (b - r) / range : 4 + (r - g) / range
            h = (h / 6 + 1).truncatingRemainder(dividingBy: 1)
        }
        hue?.pointee = h
        saturation?.pointee = high > 0 ? range / high : 0
        brightness?.pointee = high
        alpha?.pointee = a
        return true
    }

    /// Iris: the gray of the same lightness, as a dimmed tint shows.
    var irisDimmed: UIColor {
        let (r, g, b, a) = color.rgba
        return UIColor(white: 0.299 * r + 0.587 * g + 0.114 * b, alpha: a)
    }

    override open func isEqual(_ object: Any?) -> Bool {
        (object as? UIColor)?.color == color
    }

    override open var hash: Int { color.hashValue }

    override open var description: String {
        let components = color.components!.map { String(format: "%g", Double($0)) }.joined(separator: " ")
        return color.numberOfComponents == 2 ? "UIExtendedGrayColorSpace \(components)" : "UIExtendedSRGBColorSpace \(components)"
    }

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }

    // MARK: Fixed colors

    open class var black: UIColor { UIColor(white: 0, alpha: 1) }
    open class var darkGray: UIColor { UIColor(white: 1 / 3, alpha: 1) }
    open class var lightGray: UIColor { UIColor(white: 2 / 3, alpha: 1) }
    open class var white: UIColor { UIColor(white: 1, alpha: 1) }
    open class var gray: UIColor { UIColor(white: 0.5, alpha: 1) }
    open class var red: UIColor { UIColor(red: 1, green: 0, blue: 0, alpha: 1) }
    open class var green: UIColor { UIColor(red: 0, green: 1, blue: 0, alpha: 1) }
    open class var blue: UIColor { UIColor(red: 0, green: 0, blue: 1, alpha: 1) }
    open class var cyan: UIColor { UIColor(red: 0, green: 1, blue: 1, alpha: 1) }
    open class var yellow: UIColor { UIColor(red: 1, green: 1, blue: 0, alpha: 1) }
    open class var magenta: UIColor { UIColor(red: 1, green: 0, blue: 1, alpha: 1) }
    open class var orange: UIColor { UIColor(red: 1, green: 0.5, blue: 0, alpha: 1) }
    open class var purple: UIColor { UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1) }
    open class var brown: UIColor { UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1) }
    open class var clear: UIColor { UIColor(white: 0, alpha: 0) }
    open class var darkText: UIColor { .black }
    open class var lightText: UIColor { UIColor(white: 1, alpha: 0.6) }

    // MARK: System colors

    open class var systemRed: UIColor { rgb(255, 59, 48) }
    open class var systemOrange: UIColor { rgb(255, 149, 0) }
    open class var systemYellow: UIColor { rgb(255, 204, 0) }
    open class var systemGreen: UIColor { rgb(52, 199, 89) }
    open class var systemMint: UIColor { rgb(0, 199, 190) }
    open class var systemTeal: UIColor { rgb(48, 176, 199) }
    open class var systemCyan: UIColor { rgb(50, 173, 230) }
    open class var systemBlue: UIColor { rgb(0, 122, 255) }
    open class var systemIndigo: UIColor { rgb(88, 86, 214) }
    open class var systemPurple: UIColor { rgb(175, 82, 222) }
    open class var systemPink: UIColor { rgb(255, 45, 85) }
    open class var systemBrown: UIColor { rgb(162, 132, 94) }
    open class var systemGray: UIColor { rgb(142, 142, 147) }
    open class var systemGray2: UIColor { rgb(174, 174, 178) }
    open class var systemGray3: UIColor { rgb(199, 199, 204) }
    open class var systemGray4: UIColor { rgb(209, 209, 214) }
    open class var systemGray5: UIColor { rgb(229, 229, 234) }
    open class var systemGray6: UIColor { rgb(242, 242, 247) }
    open class var tintColor: UIColor { systemBlue }

    open class var label: UIColor { .black }
    open class var secondaryLabel: UIColor { rgb(60, 60, 67, 0.6) }
    open class var tertiaryLabel: UIColor { rgb(60, 60, 67, 0.3) }
    open class var quaternaryLabel: UIColor { rgb(60, 60, 67, 0.18) }
    open class var link: UIColor { systemBlue }
    open class var placeholderText: UIColor { rgb(60, 60, 67, 0.3) }
    open class var separator: UIColor { rgb(60, 60, 67, 0.29) }
    open class var opaqueSeparator: UIColor { rgb(198, 198, 200) }
    open class var systemFill: UIColor { rgb(120, 120, 128, 0.2) }
    open class var secondarySystemFill: UIColor { rgb(120, 120, 128, 0.16) }
    open class var tertiarySystemFill: UIColor { rgb(118, 118, 128, 0.12) }
    open class var quaternarySystemFill: UIColor { rgb(116, 116, 128, 0.08) }
    open class var systemBackground: UIColor { .white }
    open class var secondarySystemBackground: UIColor { rgb(242, 242, 247) }
    open class var tertiarySystemBackground: UIColor { .white }
    open class var systemGroupedBackground: UIColor { rgb(242, 242, 247) }
    open class var secondarySystemGroupedBackground: UIColor { .white }
    open class var tertiarySystemGroupedBackground: UIColor { rgb(242, 242, 247) }
}
