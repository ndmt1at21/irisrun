import Foundation

/// A color for Core Graphics and Core Animation. CoreGraphics on Linux (OpenCoreGraphics) has
/// none, so UIKit brings it.
// ponytail: sRGB and gray only, no CGColorSpace; Display P3 and the rest come with drawing.
public final class CGColor: Hashable, Sendable, CustomStringConvertible {
    /// Gray and alpha, or red, green, blue and alpha.
    private let values: [CGFloat]

    private init(values: [CGFloat]) {
        self.values = values
    }

    public convenience init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(values: [red, green, blue, alpha])
    }

    public convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(values: [red, green, blue, alpha])
    }

    public convenience init(gray: CGFloat, alpha: CGFloat) {
        self.init(values: [gray, alpha])
    }

    public convenience init(genericGrayGamma2_2Gray gray: CGFloat, alpha: CGFloat) {
        self.init(values: [gray, alpha])
    }

    public static let white = CGColor(gray: 1, alpha: 1)
    public static let black = CGColor(gray: 0, alpha: 1)
    public static let clear = CGColor(gray: 0, alpha: 0)

    public var numberOfComponents: Int { values.count }
    public var components: [CGFloat]? { values }
    public var alpha: CGFloat { values[values.count - 1] }

    public func copy(alpha: CGFloat) -> CGColor? {
        CGColor(values: values.dropLast() + [alpha])
    }

    public static func == (lhs: CGColor, rhs: CGColor) -> Bool {
        lhs.values == rhs.values
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(values)
    }

    public var description: String {
        "<CGColor \(values.count == 2 ? "gray" : "sRGB") \(values.map { "\($0)" }.joined(separator: " "))>"
    }

    /// Red, green, blue and alpha.
    var rgba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        values.count == 2 ? (values[0], values[0], values[0], values[1]) : (values[0], values[1], values[2], values[3])
    }

    /// 0xAARRGGBB, as the render core takes colors.
    var argb: UInt32 {
        let (red, green, blue, alpha) = rgba
        let byte = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return byte(alpha) << 24 | byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}
