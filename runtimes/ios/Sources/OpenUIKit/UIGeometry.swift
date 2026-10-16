import Foundation

/// Distances inward from each edge of a rectangle.
public struct UIEdgeInsets: Hashable, Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init() {
        self.init(top: 0, left: 0, bottom: 0, right: 0)
    }

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        (self.top, self.left, self.bottom, self.right) = (top, left, bottom, right)
    }

    public static let zero = UIEdgeInsets()
}

/// Insets by the leading and trailing edges, which are left and right in a left-to-right
/// language.
public struct NSDirectionalEdgeInsets: Hashable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init() {
        self.init(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        (self.top, self.leading, self.bottom, self.trailing) = (top, leading, bottom, trailing)
    }

    public static let zero = NSDirectionalEdgeInsets()

    /// Iris: as UIEdgeInsets, in a left-to-right layout.
    // ponytail: left to right only, until right-to-left languages lay out.
    var irisInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
    }
}

public struct NSDirectionalRectEdge: OptionSet, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let top = NSDirectionalRectEdge(rawValue: 1 << 0)
    public static let leading = NSDirectionalRectEdge(rawValue: 1 << 1)
    public static let bottom = NSDirectionalRectEdge(rawValue: 1 << 2)
    public static let trailing = NSDirectionalRectEdge(rawValue: 1 << 3)
    public static let all: NSDirectionalRectEdge = [.top, .leading, .bottom, .trailing]
}

extension CGRect {
    public func inset(by insets: UIEdgeInsets) -> CGRect {
        CGRect(
            x: minX + insets.left, y: minY + insets.top,
            width: width - insets.left - insets.right, height: height - insets.top - insets.bottom
        )
    }
}
