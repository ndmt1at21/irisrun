import Foundation

/// A row or a column of views, its arranged subviews, laid out by constraints it makes as
/// UIKit's stack view does, with the same identifiers (`UISV-spacing`…): along the axis by
/// `distribution` and `spacing`, across it by `alignment`, in its bounds or its layout margins.
/// Arranged views don't translate their autoresizing masks; a hidden one takes no room and no
/// spacing.
@preconcurrency @MainActor
open class UIStackView: UIView {
    public enum Distribution: Int, Sendable {
        case fill = 0, fillEqually, fillProportionally, equalSpacing, equalCentering
    }

    public enum Alignment: Int, Sendable {
        case fill = 0, leading, firstBaseline, center, trailing, lastBaseline

        public static var top: Alignment {
            .leading
        }

        public static var bottom: Alignment {
            .trailing
        }
    }

    /// As custom spacing: the stack view's `spacing`.
    nonisolated public static let spacingUseDefault = CGFloat(Float.greatestFiniteMagnitude)

    /// As spacing: the system's standard spacing.
    nonisolated public static let spacingUseSystem = CGFloat(Float.leastNormalMagnitude)

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public convenience init(arrangedSubviews views: [UIView]) {
        self.init(frame: .zero)
        for view in views {
            addArrangedSubview(view)
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open private(set) var arrangedSubviews: [UIView] = []

    open var axis = NSLayoutConstraint.Axis.horizontal {
        didSet { rearrange() }
    }

    open var distribution = Distribution.fill {
        didSet { rearrange() }
    }

    open var alignment = Alignment.fill {
        didSet { rearrange() }
    }

    /// Between neighbouring arranged views: exactly, or at least for equal spacing and equal
    /// centering.
    open var spacing: CGFloat = 0 {
        didSet { rearrange() }
    }

    /// In a column, spacing goes from the last baseline of a view's text to the first of the
    /// next one's.
    // ponytail: the first and last views still meet the edges, not their baselines.
    open var isBaselineRelativeArrangement = false {
        didSet { rearrange() }
    }

    /// Arranges the views in the layout margins rather than the bounds.
    open var isLayoutMarginsRelativeArrangement = false {
        didSet { rearrange() }
    }

    open func addArrangedSubview(_ view: UIView) {
        insertArrangedSubview(view, at: arrangedSubviews.count)
    }

    /// Arranges a view at an index, adding it as a subview if it isn't one.
    open func insertArrangedSubview(_ view: UIView, at stackIndex: Int) {
        arrangedSubviews.removeAll { $0 === view }
        arrangedSubviews.insert(view, at: min(max(stackIndex, 0), arrangedSubviews.count))
        view.translatesAutoresizingMaskIntoConstraints = false
        if view.superview !== self {
            addSubview(view)
        }
        rearrange()
    }

    /// Stops arranging a view, which stays a subview, as in UIKit.
    open func removeArrangedSubview(_ view: UIView) {
        guard arrangedSubviews.contains(where: { $0 === view }) else { return }
        arrangedSubviews.removeAll { $0 === view }
        customSpacings[ObjectIdentifier(view)] = nil
        rearrange()
    }

    /// An arranged view that leaves is no longer arranged.
    open override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        removeArrangedSubview(subview)
    }

    private var customSpacings: [ObjectIdentifier: CGFloat] = [:]

    /// Spacing after an arranged view in place of `spacing`; `spacingUseDefault` takes it back.
    open func setCustomSpacing(_ spacing: CGFloat, after arrangedSubview: UIView) {
        customSpacings[ObjectIdentifier(arrangedSubview)] = spacing == UIStackView.spacingUseDefault ? nil : spacing
        rearrange()
    }

    open func customSpacing(after arrangedSubview: UIView) -> CGFloat {
        customSpacings[ObjectIdentifier(arrangedSubview)] ?? UIStackView.spacingUseDefault
    }

    /// Proportions follow the intrinsic sizes of the arranged views.
    open override func _intrinsicContentSizeInvalidated(forChildView view: UIView) {
        if distribution == .fillProportionally, arrangedSubviews.contains(where: { $0 === view }) {
            rearrange()
        }
        super._intrinsicContentSizeInvalidated(forChildView: view)
    }

    /// Iris: an arranged view was hidden or shown.
    func irisArrangedSubviewHiddenDidChange(_ view: UIView) {
        if arrangedSubviews.contains(where: { $0 === view }) {
            rearrange()
        }
    }

    // MARK: The arrangement

    /// The constraints and guides of the arrangement, which the stack view holds.
    private var arrangement: (constraints: [NSLayoutConstraint], guides: [UILayoutGuide]) = ([], [])

    /// Makes the arrangement anew as soon as anything it depends on changed, so that the stack
    /// view has its constraints before it is laid out or measured, as by SwiftUI.
    private func rearrange() {
        removeConstraints(arrangement.constraints)
        for guide in arrangement.guides {
            removeLayoutGuide(guide)
        }
        arrangement = arrange()
        addConstraints(arrangement.constraints)
    }

    /// The spacing after an arranged view: its custom spacing or the stack view's, the system's
    /// standard spacing for `spacingUseSystem`.
    private func gap(after view: UIView) -> CGFloat {
        let gap = customSpacings[ObjectIdentifier(view)] ?? spacing
        return gap == UIStackView.spacingUseSystem ? systemSpacing : gap
    }

    /// The constraints UIKit's stack view makes for the arrangement, and the guides they place.
    private func arrange() -> (constraints: [NSLayoutConstraint], guides: [UILayoutGuide]) {
        typealias Attribute = NSLayoutConstraint.Attribute
        guard let first = arrangedSubviews.first else { return ([], []) }
        var constraints: [NSLayoutConstraint] = []
        var guides: [UILayoutGuide] = []
        func constrain(
            _ item: AnyObject, _ attribute: Attribute, _ relation: NSLayoutConstraint.Relation = .equal, _ other: AnyObject? = nil,
            _ otherAttribute: Attribute = .notAnAttribute, multiplier: CGFloat = 1, constant: CGFloat = 0,
            priority: UILayoutPriority = .required, id identifier: String
        ) {
            let constraint = NSLayoutConstraint(item, attribute, relation, other, otherAttribute, multiplier: multiplier, constant: constant, priority: priority)
            constraint.identifier = identifier
            constraints.append(constraint)
        }
        func guide(_ identifier: String) -> UILayoutGuide {
            let guide = UILayoutGuide()
            guide.identifier = identifier
            addLayoutGuide(guide)
            guides.append(guide)
            return guide
        }
        let canvas: AnyObject = isLayoutMarginsRelativeArrangement ? layoutMarginsGuide : self
        let row = axis == .horizontal
        // Along the axis, and across it.
        let (leading, trailing, length, center): (Attribute, Attribute, Attribute, Attribute) = row ? (.leading, .trailing, .width, .centerX) : (.top, .bottom, .height, .centerY)
        let (top, bottom, breadth, middle): (Attribute, Attribute, Attribute, Attribute) = row ? (.top, .bottom, .height, .centerY) : (.leading, .trailing, .width, .centerX)
        let visible = arrangedSubviews.filter { !$0.isHidden }

        // Along the axis: the first and last visible views at the ends of the canvas, spacing
        // between neighbours (at least that much when spacing is distributed), and a hidden
        // view 0 long, in the middle of the spacing it would have.
        if let firstVisible = visible.first, let lastVisible = visible.last {
            constrain(canvas, leading, .equal, firstVisible, leading, id: "UISV-canvas-connection")
            constrain(canvas, trailing, .equal, lastVisible, trailing, id: "UISV-canvas-connection")
        }
        let exact = [.fill, .fillEqually, .fillProportionally].contains(distribution)
        let baselines = isBaselineRelativeArrangement && !row
        var previous: UIView?
        for view in arrangedSubviews {
            if view.isHidden {
                constrain(view, length, id: "UISV-hiding")
                if let previous {
                    constrain(view, leading, .equal, previous, trailing, constant: previous === visible.last ? 0 : gap(after: previous) / 2, id: "UISV-spacing")
                } else {
                    constrain(view, leading, .equal, canvas, leading, id: "UISV-spacing")
                }
                continue
            }
            if let previous {
                constrain(
                    view, baselines ? .firstBaseline : leading, exact ? .equal : .greaterThanOrEqual, previous, baselines ? .lastBaseline : trailing,
                    constant: gap(after: previous), id: "UISV-spacing"
                )
            }
            previous = view
        }
        switch distribution {
        case .fill:
            break
        case .fillEqually:
            for view in visible.dropFirst() {
                constrain(view, length, .equal, visible[0], length, id: "UISV-fill-equally")
            }
        case .fillProportionally:
            // Shares of the canvas as big as the intrinsic sizes' share of their sum with the
            // spacing, the later views giving way first.
            let sizes = visible.map { max(0, row ? $0.intrinsicContentSize.width : $0.intrinsicContentSize.height) }
            let total = sizes.reduce(0, +) + zip(visible, visible.dropFirst()).map { gap(after: $0.0) }.reduce(0, +)
            for (index, (view, size)) in zip(visible, sizes).enumerated() where total > 0 {
                constrain(view, length, .equal, canvas, length, multiplier: size / total, priority: UILayoutPriority(999 - Float(index)), id: "UISV-fill-proportionally")
            }
        case .equalSpacing, .equalCentering:
            // Guides between neighbours, edge to edge or center to center, as long as each other
            // (as far as the spacing lets them, when centering).
            let centering = distribution == .equalCentering
            var spaces: [UILayoutGuide] = []
            for (before, after) in zip(visible, visible.dropFirst()) {
                let space = guide("UISV-distributing")
                constrain(space, leading, .equal, before, centering ? center : trailing, id: "UISV-distributing-edge")
                constrain(space, trailing, .equal, after, centering ? center : leading, id: "UISV-distributing-edge")
                if let firstSpace = spaces.first {
                    constrain(space, length, .equal, firstSpace, length, priority: centering ? UILayoutPriority(150) : .required, id: "UISV-fill-equally")
                }
                spaces.append(space)
            }
            // No longer than it must be, unless something else sizes it.
            if let space = spaces.first {
                constrain(space, length, priority: UILayoutPriority(25), id: "UISV-ambiguity-suppression")
            }
        }

        // Across the axis: all as broad as the canvas, or lined up by an edge, the center or a
        // baseline, in a guide that spans them and is as broad as the canvas.
        // ponytail: baselines line up rows only; a column aligned by a baseline fills.
        let aligned: Attribute? = switch alignment {
        case .fill: nil
        case .leading: top
        case .center: middle
        case .trailing: bottom
        case .firstBaseline: row ? .firstBaseline : nil
        case .lastBaseline: row ? .lastBaseline : nil
        }
        guard let aligned else {
            for view in arrangedSubviews.dropFirst() {
                constrain(view, top, .equal, first, top, id: "UISV-alignment")
                constrain(view, bottom, .equal, first, bottom, id: "UISV-alignment")
            }
            constrain(canvas, top, .equal, first, top, id: "UISV-canvas-connection")
            constrain(canvas, bottom, .equal, first, bottom, id: "UISV-canvas-connection")
            return (constraints, guides)
        }
        for view in arrangedSubviews.dropFirst() {
            constrain(view, aligned, .equal, first, aligned, id: "UISV-alignment")
        }
        let spanner = guide("UISV-alignment-spanner")
        for view in visible {
            constrain(spanner, top, alignment == .leading ? .equal : .lessThanOrEqual, view, top, id: "UISV-spanning-boundary")
            constrain(spanner, bottom, alignment == .trailing ? .equal : .greaterThanOrEqual, view, bottom, id: "UISV-spanning-boundary")
        }
        constrain(spanner, breadth, priority: UILayoutPriority(51), id: "UISV-spanning-fit")
        constrain(canvas, top, .equal, spanner, top, id: "UISV-canvas-connection")
        constrain(canvas, bottom, .equal, spanner, bottom, id: "UISV-canvas-connection")
        if alignment == .center {
            constrain(canvas, middle, .equal, first, middle, id: "UISV-canvas-connection")
        } else if alignment == .firstBaseline || alignment == .lastBaseline, let firstVisible = visible.first {
            // Lined up by baselines in a broader stack view: at the top.
            constrain(canvas, top, .equal, firstVisible, top, priority: UILayoutPriority(25), id: "UISV-ambiguity-suppression")
        }
        return (constraints, guides)
    }
}
