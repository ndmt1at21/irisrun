import Foundation

/// How much a layout wish counts against others, from 1 to `required` (1000).
public struct UILayoutPriority: Hashable, RawRepresentable, Comparable, Sendable {
    public var rawValue: Float

    public init(rawValue: Float) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: Float) {
        self.rawValue = rawValue
    }

    public static let required = UILayoutPriority(1000)
    public static let defaultHigh = UILayoutPriority(750)
    public static let dragThatCanResizeScene = UILayoutPriority(510)
    public static let sceneSizeStayPut = UILayoutPriority(500)
    public static let dragThatCannotResizeScene = UILayoutPriority(490)
    public static let defaultLow = UILayoutPriority(250)
    public static let fittingSizeLevel = UILayoutPriority(50)

    public static func < (lhs: UILayoutPriority, rhs: UILayoutPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func + (lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        UILayoutPriority(lhs.rawValue + rhs)
    }

    public static func - (lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        UILayoutPriority(lhs.rawValue - rhs)
    }
}

/// A relation between layout attributes of two items, views or layout guides, that Auto Layout
/// keeps while the constraint is active, as far as its priority lets it:
/// `firstItem.firstAttribute <relation> multiplier × secondItem.secondAttribute + constant`.
// ponytail: no visual format language (constraints(withVisualFormat:)) yet.
@preconcurrency @MainActor
open class NSLayoutConstraint: NSObject {
    public enum Axis: Int, Sendable {
        case horizontal = 0
        case vertical = 1
    }

    public enum Attribute: Int, Sendable {
        case left = 1, right, top, bottom, leading, trailing, width, height, centerX, centerY
        case lastBaseline = 11
        case firstBaseline = 12
        case leftMargin = 13, rightMargin, topMargin, bottomMargin, leadingMargin, trailingMargin
        case centerXWithinMargins = 19, centerYWithinMargins
        case notAnAttribute = 0

        public static var baseline: Attribute {
            .lastBaseline
        }
    }

    public enum Relation: Int, Sendable {
        case lessThanOrEqual = -1
        case equal = 0
        case greaterThanOrEqual = 1
    }

    /// Checks the attributes as UIKit does, which raises an exception for a pair it can't lay out.
    public convenience init(
        item view1: Any, attribute attr1: NSLayoutConstraint.Attribute, relatedBy relation: NSLayoutConstraint.Relation,
        toItem view2: Any?, attribute attr2: NSLayoutConstraint.Attribute, multiplier: CGFloat, constant c: CGFloat
    ) {
        let second = view2.map { $0 as AnyObject }
        let attr2 = second == nil ? .notAnAttribute : attr2
        if attr1 == .notAnAttribute {
            fatalError("*** +[NSLayoutConstraint constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:]: Unknown layout attribute")
        }
        if attr1.kind != .dimension, second == nil || multiplier == 0 {
            fatalError("*** +[NSLayoutConstraint constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:]: A multiplier of 0 or a nil second item together with a location for the first attribute creates an illegal constraint of a location equal to a constant. Location attributes must be specified in pairs.")
        }
        if second != nil {
            if (attr1.kind == .dimension) != (attr2.kind == .dimension) || attr1.kind != .dimension && attr1.kind != attr2.kind {
                fatalError("*** +[NSLayoutConstraint constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:]: Invalid pairing of layout attributes.")
            }
            if attr1.isDirectional && attr2.isAbsolute || attr1.isAbsolute && attr2.isDirectional {
                fatalError("*** +[NSLayoutConstraint constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:]: A constraint cannot be made between a leading/trailing attribute and a right/left attribute. Use leading/trailing for both or neither.")
            }
        }
        self.init(view1 as AnyObject, attr1, relation, second, attr2, multiplier: multiplier, constant: c)
    }

    /// Iris: any pair of attributes, as the constraints UIKit makes for autoresizing masks and
    /// layout guides relate a location to a size or a location to a constant.
    init(
        _ item: AnyObject, _ attribute: Attribute, _ relation: Relation = .equal, _ toItem: AnyObject? = nil,
        _ toAttribute: Attribute = .notAnAttribute, multiplier: CGFloat = 1, constant: CGFloat = 0,
        priority: UILayoutPriority = .required, kind: String = "NSLayoutConstraint"
    ) {
        irisOrder = NSLayoutConstraint.made
        NSLayoutConstraint.made += 1
        firstItem = item
        firstAttribute = attribute
        self.relation = relation
        secondItem = toAttribute == .notAnAttribute ? nil : toItem
        secondAttribute = toItem == nil ? .notAnAttribute : toAttribute
        self.multiplier = multiplier
        self.constant = constant
        self.priority = priority
        irisKind = kind
        super.init()
    }

    open private(set) weak var firstItem: AnyObject?
    open private(set) weak var secondItem: AnyObject?
    open private(set) var firstAttribute: Attribute
    open private(set) var secondAttribute: Attribute
    open private(set) var relation: Relation
    open private(set) var multiplier: CGFloat

    open var constant: CGFloat {
        didSet {
            if constant != oldValue { irisEngine?.constraintDidChange(self) }
        }
    }

    /// Optional constraints may change priority while active; a required one may not become
    /// optional then, nor the other way round, as in UIKit.
    open var priority: UILayoutPriority {
        didSet {
            guard priority != oldValue, isActive || irisEngine != nil else { return }
            if (priority == .required) != (oldValue == .required) {
                fatalError("Mutating a priority from required to not on an installed constraint (or vice-versa) is not supported.  You passed priority \(priority.rawValue) and the existing priority was \(oldValue.rawValue).")
            }
            irisEngine?.constraintDidChange(self)
        }
    }

    open var identifier: String?

    open var shouldBeArchived = false

    open var firstAnchor: NSLayoutAnchor<AnyObject> {
        NSLayoutAnchor(item: firstItem, attribute: firstAttribute)
    }

    open var secondAnchor: NSLayoutAnchor<AnyObject>? {
        secondItem.map { NSLayoutAnchor(item: $0, attribute: secondAttribute) }
    }

    /// Active constraints are held by the closest view their items are in.
    open var isActive: Bool {
        get { holder != nil }
        set {
            guard newValue != isActive else { return }
            if newValue {
                guard let first = firstItem, let view = commonView(first, secondItem) else {
                    fatalError("Unable to activate constraint with anchors \(firstAnchor) and \(secondAnchor.map(String.init(describing:)) ?? "nil") because they have no common ancestor.  Does the constraint or its anchors reference items in different view hierarchies?  That's illegal.")
                }
                view.addConstraint(self)
            } else {
                holder?.removeConstraint(self)
            }
        }
    }

    open class func activate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.isActive = true
        }
    }

    open class func deactivate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.isActive = false
        }
    }

    // MARK: Iris

    /// The view whose `constraints` it is in.
    weak var holder: UIView?
    /// The engine solving it, told when it changes.
    weak var irisEngine: LayoutEngine?
    /// The class UIKit makes it with, for the description.
    let irisKind: String
    /// The order constraints were made in, for logs.
    let irisOrder: Int
    private static var made = 0

    /// As UIKit describes constraints, such as
    /// `<NSLayoutConstraint:0x… UILabel:0x…'Title'.leading == UIView:0x….leadingMargin + 20   (active)>`.
    nonisolated override open var description: String {
        MainActor.assumeIsolated {
            var text = "<\(irisKind):\(address(of: self)) "
            if let identifier { text += "'\(identifier)' " }
            if irisKind == "NSAutoresizingMaskLayoutConstraint", let view = firstItem as? UIView {
                text += view.autoresizingMask.irisNotation + " "
            }
            text += "\(itemName(firstItem)).\(firstAttribute.name) \(relation.symbol) "
            if let secondItem {
                text += (multiplier == 1 ? "" : "\(number(multiplier))*") + "\(itemName(secondItem)).\(secondAttribute.name)"
                if constant != 0 { text += (constant > 0 ? " + " : " - ") + number(abs(constant)) }
            } else {
                text += number(constant)
            }
            if priority != .required { text += " @\(number(CGFloat(priority.rawValue)))" }
            return text + (isActive || irisEngine != nil ? "   (active)>" : "   (inactive)>")
        }
    }
}

/// Where a constraint of two items goes: the closest view both are in, or the first item's
/// view (a guide's owning view) for a constraint of one.
@MainActor
func commonView(_ first: AnyObject, _ second: AnyObject?) -> UIView? {
    guard let firstView = layoutView(of: first) else { return nil }
    guard let second else { return firstView }
    guard let secondView = layoutView(of: second) else { return nil }
    let depth = { (view: UIView) in sequence(first: view, next: \.superview).reduce(0) { count, _ in count + 1 } }
    var (a, b) = (firstView, secondView)
    var (depthA, depthB) = (depth(a), depth(b))
    while depthA > depthB, let superview = a.superview { (a, depthA) = (superview, depthA - 1) }
    while depthB > depthA, let superview = b.superview { (b, depthB) = (superview, depthB - 1) }
    while a !== b {
        guard let superA = a.superview, let superB = b.superview else { return nil }
        (a, b) = (superA, superB)
    }
    return a
}

/// The view an item is, or the view that owns a layout guide.
@MainActor
func layoutView(of item: AnyObject) -> UIView? {
    item as? UIView ?? (item as? UILayoutGuide)?.owningView
}

@MainActor
private func itemName(_ item: AnyObject?) -> String {
    guard let item else { return "nil" }
    var name = "\(String(describing: type(of: item)).prefix { $0 != "<" }):\(address(of: item))"
    if let label = item as? UILabel, let text = label.text {
        name += "'\(text)'"
    } else if let guide = item as? UILayoutGuide, !guide.identifier.isEmpty {
        name += "'\(guide.identifier)'"
    }
    return name
}

func address(of object: AnyObject) -> String {
    "0x" + String(UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque()), radix: 16)
}

private func number(_ value: CGFloat) -> String {
    String(format: "%g", Double(value))
}

extension NSLayoutConstraint.Attribute {
    enum Kind {
        case horizontal, vertical, dimension
    }

    var kind: Kind {
        switch self {
        case .left, .right, .leading, .trailing, .centerX, .leftMargin, .rightMargin, .leadingMargin, .trailingMargin, .centerXWithinMargins: .horizontal
        case .width, .height, .notAnAttribute: .dimension
        default: .vertical
        }
    }

    /// Leading and trailing, which UIKit won't pair with left and right.
    var isDirectional: Bool {
        [.leading, .trailing, .leadingMargin, .trailingMargin].contains(self)
    }

    var isAbsolute: Bool {
        [.left, .right, .leftMargin, .rightMargin].contains(self)
    }

    /// The attribute of the margins guide that a margin attribute is.
    var withoutMargin: Self? {
        switch self {
        case .leftMargin: .left
        case .rightMargin: .right
        case .topMargin: .top
        case .bottomMargin: .bottom
        case .leadingMargin: .leading
        case .trailingMargin: .trailing
        case .centerXWithinMargins: .centerX
        case .centerYWithinMargins: .centerY
        default: nil
        }
    }

    var name: String {
        switch self {
        case .left: "left"
        case .right: "right"
        case .top: "top"
        case .bottom: "bottom"
        case .leading: "leading"
        case .trailing: "trailing"
        case .width: "width"
        case .height: "height"
        case .centerX: "centerX"
        case .centerY: "centerY"
        case .lastBaseline: "lastBaseline"
        case .firstBaseline: "firstBaseline"
        case .leftMargin: "leftMargin"
        case .rightMargin: "rightMargin"
        case .topMargin: "topMargin"
        case .bottomMargin: "bottomMargin"
        case .leadingMargin: "leadingMargin"
        case .trailingMargin: "trailingMargin"
        case .centerXWithinMargins: "centerXWithinMargins"
        case .centerYWithinMargins: "centerYWithinMargins"
        case .notAnAttribute: "notAnAttribute"
        }
    }
}

extension NSLayoutConstraint.Relation {
    var symbol: String {
        switch self {
        case .lessThanOrEqual: "<="
        case .equal: "=="
        case .greaterThanOrEqual: ">="
        }
    }
}

// MARK: - Anchors

/// One layout attribute of a view or layout guide, which makes constraints with another of
/// the same kind: `view.leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: 16)`.
@preconcurrency @MainActor
open class NSLayoutAnchor<AnchorType: AnyObject>: NSObject, NSCopying {
    init(item: AnyObject?, attribute: NSLayoutConstraint.Attribute) {
        self.item = item
        self.attribute = attribute
        super.init()
    }

    open private(set) weak var item: AnyObject?
    let attribute: NSLayoutConstraint.Attribute

    open var name: String {
        attribute.name
    }

    nonisolated open func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    nonisolated override open var description: String {
        MainActor.assumeIsolated { "\(itemName(item)).\(attribute.name)" }
    }

    open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint {
        constraint(.equal, anchor, constant: 0)
    }

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, constant: 0)
    }

    open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, constant: 0)
    }

    open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, anchor, constant: c)
    }

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, constant: c)
    }

    open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, constant: c)
    }

    /// A constraint from this anchor to `anchor` (nil for a constant size).
    final func constraint(
        _ relation: NSLayoutConstraint.Relation, _ anchor: NSLayoutAnchor<AnchorType>?, multiplier: CGFloat = 1, constant: CGFloat
    ) -> NSLayoutConstraint {
        guard let item else {
            fatalError("A constraint cannot be made from an anchor whose item is gone.")
        }
        return NSLayoutConstraint(item, attribute, relation, anchor?.item, anchor?.attribute ?? .notAnAttribute, multiplier: multiplier, constant: constant)
    }
}

/// The standard space between two views, which UIKit's system spacing is.
// ponytail: also between text baselines, where UIKit derives it from the fonts.
private let systemSpacing: CGFloat = 8

@preconcurrency @MainActor
open class NSLayoutXAxisAnchor: NSLayoutAnchor<NSLayoutXAxisAnchor> {
    open func constraint(equalToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, anchor, constant: systemSpacing * multiplier)
    }

    open func constraint(greaterThanOrEqualToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, constant: systemSpacing * multiplier)
    }

    open func constraint(lessThanOrEqualToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, constant: systemSpacing * multiplier)
    }
}

@preconcurrency @MainActor
open class NSLayoutYAxisAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {
    open func constraint(equalToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, anchor, constant: systemSpacing * multiplier)
    }

    open func constraint(greaterThanOrEqualToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, constant: systemSpacing * multiplier)
    }

    open func constraint(lessThanOrEqualToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, constant: systemSpacing * multiplier)
    }
}

/// A width or height, which also makes constraints to a constant and to a multiple of
/// another size.
@preconcurrency @MainActor
open class NSLayoutDimension: NSLayoutAnchor<NSLayoutDimension> {
    open func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, nil, constant: c)
    }

    open func constraint(greaterThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, nil, constant: c)
    }

    open func constraint(lessThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, nil, constant: c)
    }

    open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, anchor, multiplier: m, constant: 0)
    }

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, multiplier: m, constant: 0)
    }

    open func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, multiplier: m, constant: 0)
    }

    open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.equal, anchor, multiplier: m, constant: c)
    }

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.greaterThanOrEqual, anchor, multiplier: m, constant: c)
    }

    open func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint {
        constraint(.lessThanOrEqual, anchor, multiplier: m, constant: c)
    }
}
