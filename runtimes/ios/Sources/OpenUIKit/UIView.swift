import Foundation
import IrisHost

/// A rectangle on screen and the views inside it, drawn by its layer.
// ponytail: no drawing with Core Graphics in draw(_:), no transitions, keyframe or property
// animators, and no traits yet; they come with the later steps of P1-16.
@preconcurrency @MainActor
open class UIView: UIResponder, @preconcurrency NSCoding {
    open class var layerClass: AnyClass {
        CALayer.self
    }

    public init(frame: CGRect) {
        layer = makeLayer(of: Self.layerClass)
        super.init()
        _ = UIView.ownMethods
        layer.delegate = self
        self.frame = frame
    }

    /// Views come from code only until storyboards and XIBs are read (P1-16, step 6).
    public required init?(coder: NSCoder) {
        layer = makeLayer(of: Self.layerClass)
        super.init()
        _ = UIView.ownMethods
        layer.delegate = self
    }

    public override convenience init() {
        self.init(frame: .zero)
    }

    open func encode(with coder: NSCoder) {}

    open private(set) var layer: CALayer

    /// The view controller whose view this is.
    weak var viewController: UIViewController?

    override open var next: UIResponder? {
        viewController ?? superview
    }

    // MARK: Geometry

    open var frame: CGRect {
        get { layer.frame }
        set { resize { layer.frame = newValue } }
    }

    open var bounds: CGRect {
        get { layer.bounds }
        set { resize { layer.bounds = newValue } }
    }

    open var center: CGPoint {
        get { layer.position }
        set { layer.position = newValue }
    }

    open var transform: CGAffineTransform {
        get { layer.affineTransform() }
        set { layer.setAffineTransform(newValue) }
    }

    /// Runs a change of the bounds, then lays out and autoresizes the subviews if their size
    /// changed.
    private func resize(_ change: () -> Void) {
        let oldSize = bounds.size
        change()
        let newSize = bounds.size
        guard newSize != oldSize else { return }
        setNeedsLayout()
        if contentMode == .redraw {
            setNeedsDisplay()
        }
        guard autoresizesSubviews else { return }
        for subview in subviews where !subview.autoresizingMask.isEmpty {
            subview.frame = subview.autoresizingMask.resizing(subview.frame, from: oldSize, to: newSize)
        }
    }

    open var autoresizesSubviews = true

    open var autoresizingMask: UIView.AutoresizingMask = []

    open func sizeThatFits(_ size: CGSize) -> CGSize {
        bounds.size
    }

    open func sizeToFit() {
        frame.size = sizeThatFits(bounds.size)
    }

    /// The size the view's content wants, or `noIntrinsicMetric` along an axis where it has
    /// none; Auto Layout sizes views that don't translate their autoresizing mask by it.
    open var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    /// Tells Auto Layout and the superview, which lay out by it: a SwiftUI view of a
    /// UIViewRepresentable sizes the view anew.
    open func invalidateIntrinsicContentSize() {
        irisRootView.layoutEngine?.contentDidChange(self)
        superview?._intrinsicContentSizeInvalidated(forChildView: self)
    }

    /// Iris: whether the intrinsic height depends on the width layout gives the view, as a
    /// label's that wraps lines at its width.
    var irisWrapsAtLayoutWidth: Bool {
        false
    }

    /// Iris: the intrinsic content size, with lines wrapped at `width` for a view that wraps.
    func irisContentSize(wrappingAt width: CGFloat?) -> CGSize {
        intrinsicContentSize
    }

    /// Iris: how far below the view's middle its text's first and last baselines are; nil for
    /// a view without text, whose baselines are its bottom edge.
    var irisBaselineOffsets: (first: CGFloat, last: CGFloat)? {
        nil
    }

    /// Iris: a subview's intrinsic content size changed, as UIKit tells views that host
    /// others; a view that sizes from its subviews' overrides it. A view whose constraints
    /// place its subviews may change size with them, so it tells its superview in turn.
    open func _intrinsicContentSizeInvalidated(forChildView view: UIView) {
        if !constraints.isEmpty {
            superview?._intrinsicContentSizeInvalidated(forChildView: self)
        }
    }

    nonisolated public static let noIntrinsicMetric: CGFloat = -1

    // MARK: Content priorities

    /// How much the view resists growing past its intrinsic content size (250 unless set) and
    /// shrinking below it (750), along each axis: what Auto Layout and SwiftUI size it by.
    private var priorities: (hugging: [UILayoutPriority], compression: [UILayoutPriority]) = ([.defaultLow, .defaultLow], [.defaultHigh, .defaultHigh])

    open func contentHuggingPriority(for axis: NSLayoutConstraint.Axis) -> UILayoutPriority {
        priorities.hugging[axis.rawValue]
    }

    open func setContentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
        priorities.hugging[axis.rawValue] = priority
        irisRootView.layoutEngine?.contentDidChange(self)
    }

    open func contentCompressionResistancePriority(for axis: NSLayoutConstraint.Axis) -> UILayoutPriority {
        priorities.compression[axis.rawValue]
    }

    open func setContentCompressionResistancePriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
        priorities.compression[axis.rawValue] = priority
        irisRootView.layoutEngine?.contentDidChange(self)
    }

    open func convert(_ point: CGPoint, to view: UIView?) -> CGPoint {
        layer.convert(point, to: (view ?? window)?.layer)
    }

    open func convert(_ point: CGPoint, from view: UIView?) -> CGPoint {
        layer.convert(point, from: (view ?? window)?.layer)
    }

    open func convert(_ rect: CGRect, to view: UIView?) -> CGRect {
        layer.convert(rect, to: (view ?? window)?.layer)
    }

    open func convert(_ rect: CGRect, from view: UIView?) -> CGRect {
        layer.convert(rect, from: (view ?? window)?.layer)
    }

    open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    /// The front-most view at a point in this view's coordinates that takes touches.
    open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha >= 0.01, self.point(inside: point, with: event) else {
            return nil
        }
        for subview in subviews.reversed() {
            if let hit = subview.hitTest(subview.convert(point, from: self), with: event) {
                return hit
            }
        }
        return self
    }

    // MARK: Appearance

    open var backgroundColor: UIColor? {
        didSet { layer.backgroundColor = backgroundColor?.cgColor }
    }

    open var alpha: CGFloat {
        get { CGFloat(layer.opacity) }
        set { layer.opacity = Float(newValue) }
    }

    open var isHidden: Bool {
        get { layer.isHidden }
        set {
            guard newValue != layer.isHidden else { return }
            layer.isHidden = newValue
            // A stack view gives the room of an arranged view to the others while it is hidden.
            (superview as? UIStackView)?.irisArrangedSubviewHiddenDidChange(self)
        }
    }

    open var clipsToBounds: Bool {
        get { layer.masksToBounds }
        set { layer.masksToBounds = newValue }
    }

    open var isOpaque = true

    /// How the layer shows its contents in the bounds, which UIKit sets as the layer's gravity.
    open var contentMode = UIView.ContentMode.scaleToFill {
        didSet { layer.contentsGravity = contentMode.contentsGravity }
    }

    open var tag = 0

    open var isUserInteractionEnabled = true

    /// Off by default: the view gets the first finger that touches it and not the others.
    open var isMultipleTouchEnabled = false

    /// While a finger touches this view, no other view in the window gets touches.
    open var isExclusiveTouch = false

    open var accessibilityLabel: String?

    /// What the view holds, as VoiceOver reads it after the label: a text field's text.
    open var accessibilityValue: String?

    open var accessibilityIdentifier: String?

    // MARK: Safe area

    /// How far the screen's safe area (clear of the Dynamic Island and the home indicator) is
    /// inside the view's bounds.
    // ponytail: from the window's frame on the screen; no additionalSafeAreaInsets, and
    // safeAreaInsetsDidChange is called only for views whose safeAreaLayoutGuide constraints
    // use.
    open var safeAreaInsets: UIEdgeInsets {
        guard let window else { return .zero }
        let safe = window.bounds.inset(by: window.safeAreaInsets)
        let frame = convert(bounds, to: window)
        return UIEdgeInsets(
            top: max(0, min(safe.minY - frame.minY, frame.height)), left: max(0, min(safe.minX - frame.minX, frame.width)),
            bottom: max(0, min(frame.maxY - safe.maxY, frame.height)), right: max(0, min(frame.maxX - safe.maxX, frame.width))
        )
    }

    open func safeAreaInsetsDidChange() {}

    // MARK: Tint

    /// The tint set on this view, if any.
    private var ownTint: UIColor?

    /// The color of the view's active parts, as system controls draw them: the view's own, or
    /// its superview's, or system blue, grayed out where the tint is dimmed.
    open var tintColor: UIColor! {
        get {
            let color = inheritedTint
            return isTintDimmed ? color.irisDimmed : color
        }
        set {
            ownTint = newValue
            tintDidChange()
        }
    }

    private var inheritedTint: UIColor {
        ownTint ?? superview?.inheritedTint ?? .systemBlue
    }

    open var tintAdjustmentMode = UIView.TintAdjustmentMode.automatic {
        didSet { tintDidChange() }
    }

    private var isTintDimmed: Bool {
        tintAdjustmentMode == .automatic ? superview?.isTintDimmed ?? false : tintAdjustmentMode == .dimmed
    }

    /// Called when the tint this view draws with changed, here or up the hierarchy.
    open func tintColorDidChange() {}

    /// Tells this view and the views inside it that take its tint that the tint changed.
    private func tintDidChange() {
        tintColorDidChange()
        for subview in subviews where subview.ownTint == nil || subview.tintAdjustmentMode == .automatic {
            subview.tintDidChange()
        }
    }

    // MARK: Drawing

    /// Has the view draw itself before it is next shown.
    open func setNeedsDisplay() {
        layer.setNeedsDisplay()
    }

    open func setNeedsDisplay(_ rect: CGRect) {
        layer.setNeedsDisplay()
    }

    /// Draws the view's content. UIKit's own views draw through the render core here.
    // ponytail: no Core Graphics context to draw into yet (UIGraphicsGetCurrentContext).
    open func draw(_ rect: CGRect) {}

    /// Iris: the layer's `display()`.
    func irisDisplay() {
        draw(bounds)
    }

    /// Makes the first responder resign if it is this view or one inside it; with `force`,
    /// even if it refuses.
    @discardableResult
    open func endEditing(_ force: Bool) -> Bool {
        guard let first = UIResponder.first as? UIView, first.isDescendant(of: self) else { return true }
        guard force else { return first.resignFirstResponder() }
        UIResponder.forceResign()
        return true
    }

    /// UIKit's own methods that apps name with selectors, such as a tap recognizer with
    /// `#selector(UIView.endEditing(_:))` that puts the keyboard away.
    private static let ownMethods: Void = _IrisMethods.register(UIView.self, [
        // The sender comes in place of the flag, as Objective-C passes it: any object forces.
        "endEditing:": .init { (view: UIView) in { (force: Any?) in view.endEditing(force as? Bool ?? (force != nil)) } },
        "removeFromSuperview": .init { (view: UIView) in { view.removeFromSuperview() } },
        "setNeedsLayout": .init { (view: UIView) in { view.setNeedsLayout() } },
        "layoutIfNeeded": .init { (view: UIView) in { view.layoutIfNeeded() } },
    ])

    // MARK: Gesture recognizers

    private var recognizers: [UIGestureRecognizer] = []

    open var gestureRecognizers: [UIGestureRecognizer]? {
        get { recognizers.isEmpty ? nil : recognizers }
        set {
            for recognizer in recognizers {
                removeGestureRecognizer(recognizer)
            }
            for recognizer in newValue ?? [] {
                addGestureRecognizer(recognizer)
            }
        }
    }

    /// Attaches a recognizer, taking it from the view it was attached to.
    open func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.view !== self else { return }
        gestureRecognizer.view?.removeGestureRecognizer(gestureRecognizer)
        recognizers.append(gestureRecognizer)
        gestureRecognizer.view = self
    }

    /// Detaches a recognizer, cancelling the gesture it was recognizing.
    open func removeGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.view === self else { return }
        recognizers.removeAll { $0 === gestureRecognizer }
        if gestureRecognizer.state != .possible || !gestureRecognizer.touches.isEmpty {
            gestureRecognizer.state = gestureRecognizer.state == .possible ? .failed : .cancelled
        }
        gestureRecognizer.view = nil
    }

    /// Asked before a recognizer of this view, or of a superview, recognizes in touches on
    /// this view; false makes it fail.
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: Hierarchy

    open private(set) weak var superview: UIView?

    open private(set) var subviews: [UIView] = []

    /// The window the view is in; nil for a window itself.
    open var window: UIWindow? {
        var view = superview
        while let current = view {
            if let window = current as? UIWindow { return window }
            view = current.superview
        }
        return nil
    }

    open func addSubview(_ view: UIView) {
        insertSubview(view, at: subviews.count - (view.superview === self ? 1 : 0))
    }

    open func insertSubview(_ view: UIView, at index: Int) {
        let oldWindow = view.window
        let newWindow = self as? UIWindow ?? window
        if view.superview !== self {
            view.willMove(toSuperview: self)
        }
        if newWindow !== oldWindow {
            view.forEachInTree { $0.willMove(toWindow: newWindow) }
        }
        let moved = view.superview === self
        if let superview = view.superview {
            if !moved { superview.willRemoveSubview(view) }
            superview.subviews.removeAll { $0 === view }
        }
        let index = min(max(index, 0), subviews.count)
        subviews.insert(view, at: index)
        view.superview = self
        // Subview layers keep their order among the layers added to this view's layer directly.
        if index + 1 < subviews.count {
            layer.insertSublayer(view.layer, below: subviews[index + 1].layer)
        } else {
            layer.addSublayer(view.layer)
        }
        if newWindow !== oldWindow {
            view.forEachInTree { $0.didMoveToWindow() }
        }
        if !moved {
            view.didMoveToSuperview()
            didAddSubview(view)
            view.tintDidChange()
        }
        // The hierarchy's Auto Layout engine takes over the view's constraints.
        if view.layoutEngine != nil || type(of: view).requiresConstraintBasedLayout {
            view.layoutEngine = nil
            irisRootView.irisMakeLayoutEngine().setNeedsSync()
        } else {
            irisRootView.layoutEngine?.setNeedsSync()
        }
        setNeedsLayout()
        view.setNeedsLayout()
    }

    open func insertSubview(_ view: UIView, belowSubview siblingSubview: UIView) {
        let index = subviews.firstIndex { $0 === siblingSubview } ?? 0
        insertSubview(view, at: index - (view.superview === self && (subviews.firstIndex { $0 === view } ?? 0) < index ? 1 : 0))
    }

    open func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        let index = subviews.firstIndex { $0 === siblingSubview }.map { $0 + 1 } ?? subviews.count
        insertSubview(view, at: index - (view.superview === self && (subviews.firstIndex { $0 === view } ?? 0) < index ? 1 : 0))
    }

    open func bringSubviewToFront(_ view: UIView) {
        guard view.superview === self else { return }
        insertSubview(view, at: subviews.count - 1)
    }

    open func sendSubviewToBack(_ view: UIView) {
        guard view.superview === self else { return }
        insertSubview(view, at: 0)
    }

    open func removeFromSuperview() {
        guard let superview else { return }
        // Constraints of the views around to this view or to views inside it go, as in UIKit;
        // the view keeps those inside it, in an engine of its own.
        var holder: UIView? = superview
        while let current = holder {
            current.removeConstraints(current.constraints.filter { constraint in
                [constraint.firstItem, constraint.secondItem].contains { $0.flatMap(layoutView(of:))?.isDescendant(of: self) == true }
            })
            holder = current.superview
        }
        if let engine = irisRootView.layoutEngine {
            engine.setNeedsSync()
            layoutEngine = LayoutEngine(host: self)
        }
        let oldWindow = window
        superview.willRemoveSubview(self)
        willMove(toSuperview: nil)
        if oldWindow != nil {
            forEachInTree { $0.willMove(toWindow: nil) }
        }
        superview.subviews.removeAll { $0 === self }
        self.superview = nil
        layer.removeFromSuperlayer()
        if oldWindow != nil {
            forEachInTree { $0.didMoveToWindow() }
            // A first responder that leaves its window resigns, as in UIKit.
            if let first = UIResponder.first as? UIView, first.isDescendant(of: self) {
                UIResponder.forceResign()
            }
        }
        didMoveToSuperview()
    }

    open func isDescendant(of view: UIView) -> Bool {
        var current: UIView? = self
        while let candidate = current {
            if candidate === view { return true }
            current = candidate.superview
        }
        return false
    }

    open func viewWithTag(_ tag: Int) -> UIView? {
        if self.tag == tag { return self }
        for subview in subviews {
            if let found = subview.viewWithTag(tag) { return found }
        }
        return nil
    }

    open func didAddSubview(_ subview: UIView) {}
    open func willRemoveSubview(_ subview: UIView) {}
    open func willMove(toSuperview newSuperview: UIView?) {}
    open func didMoveToSuperview() {}
    open func willMove(toWindow newWindow: UIWindow?) {}
    open func didMoveToWindow() {}

    /// This view, then every view inside it, depth first.
    func forEachInTree(_ body: (UIView) -> Void) {
        body(self)
        for subview in subviews {
            subview.forEachInTree(body)
        }
    }

    // MARK: Layout

    open func setNeedsLayout() {
        layer.setNeedsLayout()
    }

    open func layoutIfNeeded() {
        irisLayout { layer.layoutIfNeeded() }
    }

    /// Gives the subviews that constraints place the frames Auto Layout solved for them, as
    /// UIKit's implementation does: overrides call it first, then lay out by hand.
    open func layoutSubviews() {
        guard let engine = irisRootView.layoutEngine else { return }
        for subview in subviews where !subview.translatesAutoresizingMaskIntoConstraints {
            guard let frame = engine.frame(of: subview) else { continue }
            let anchor = subview.layer.anchorPoint
            let center = CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
            if subview.bounds.size != frame.size {
                subview.bounds.size = frame.size
            }
            if subview.center != center {
                subview.center = center
            }
        }
    }

    // MARK: Auto Layout

    /// The constraints this view holds: activating a constraint puts it in the closest view
    /// its items are in.
    open private(set) var constraints: [NSLayoutConstraint] = []

    open func addConstraint(_ constraint: NSLayoutConstraint) {
        guard constraint.holder !== self else { return }
        constraint.holder?.removeConstraint(constraint)
        constraints.append(constraint)
        constraint.holder = self
        irisRootView.irisMakeLayoutEngine().setNeedsSync()
    }

    open func addConstraints(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            addConstraint(constraint)
        }
    }

    open func removeConstraint(_ constraint: NSLayoutConstraint) {
        guard constraint.holder === self else { return }
        constraints.removeAll { $0 === constraint }
        constraint.holder = nil
        irisRootView.layoutEngine?.setNeedsSync()
    }

    open func removeConstraints(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            removeConstraint(constraint)
        }
    }

    /// True keeps the frame as set, Auto Layout turning the autoresizing mask into constraints;
    /// false lets constraints place the view.
    open var translatesAutoresizingMaskIntoConstraints = true {
        didSet {
            if translatesAutoresizingMaskIntoConstraints != oldValue { irisRootView.layoutEngine?.setNeedsSync() }
        }
    }

    /// True has UIKit run the update-constraints pass for a hierarchy with a view of the class,
    /// whether or not it has constraints yet.
    open class var requiresConstraintBasedLayout: Bool {
        false
    }

    private var constraintsNeedUpdate = true

    open func setNeedsUpdateConstraints() {
        constraintsNeedUpdate = true
        irisRootView.layoutEngine?.setNeedsSync()
    }

    open func needsUpdateConstraints() -> Bool {
        constraintsNeedUpdate
    }

    /// Runs `updateConstraints` where needed in this view and the views inside it, from the
    /// leaves up as UIKit does; a view controller's view asks its controller.
    open func updateConstraintsIfNeeded() {
        for subview in subviews {
            subview.updateConstraintsIfNeeded()
        }
        guard constraintsNeedUpdate else { return }
        constraintsNeedUpdate = false
        if let viewController {
            viewController.updateViewConstraints()
        } else {
            updateConstraints()
        }
    }

    /// Changes the view's constraints before layout; overrides call super last.
    open func updateConstraints() {}

    /// Iris: the Auto Layout engine of the hierarchy this view is the top of.
    var layoutEngine: LayoutEngine?

    /// Iris: the top of the hierarchy, which keeps the Auto Layout engine.
    var irisRootView: UIView {
        var view = self
        while let superview = view.superview {
            view = superview
        }
        return view
    }

    func irisMakeLayoutEngine() -> LayoutEngine {
        if let layoutEngine { return layoutEngine }
        let engine = LayoutEngine(host: self)
        layoutEngine = engine
        return engine
    }

    nonisolated public static let layoutFittingCompressedSize = CGSize(width: 0, height: 0)
    nonisolated public static let layoutFittingExpandedSize = CGSize(width: 10_000_000, height: 10_000_000)

    /// The size the constraints inside the view give it, as close to `targetSize` as they let.
    open func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)
    }

    /// The size the constraints inside the view give it, as close to `targetSize` along each
    /// axis as the priority lets it: required keeps that side.
    open func systemLayoutSizeFitting(
        _ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let engine = LayoutEngine(host: self, fitting: (targetSize, horizontalFittingPriority, verticalFittingPriority))
        engine.update()
        return engine.hostSize
    }

    /// Whether the view's constraints leave it more than one frame.
    open var hasAmbiguousLayout: Bool {
        irisRootView.layoutEngine?.alternativeFrame(of: self) != nil
    }

    /// Moves a view whose layout is ambiguous to another frame its constraints allow.
    open func exerciseAmbiguityInLayout() {
        if let frame = irisRootView.layoutEngine?.alternativeFrame(of: self) {
            self.frame = frame
        }
    }

    // MARK: Layout guides and margins

    open private(set) var layoutGuides: [UILayoutGuide] = []

    open func addLayoutGuide(_ layoutGuide: UILayoutGuide) {
        layoutGuide.owningView?.removeLayoutGuide(layoutGuide)
        layoutGuides.append(layoutGuide)
        layoutGuide.owningView = self
        irisRootView.layoutEngine?.setNeedsSync()
    }

    /// Takes the guide out, with the constraints that place it, as UIKit does.
    open func removeLayoutGuide(_ layoutGuide: UILayoutGuide) {
        guard layoutGuide.owningView === self else { return }
        var holder: UIView? = self
        while let current = holder {
            current.removeConstraints(current.constraints.filter { $0.firstItem === layoutGuide || $0.secondItem === layoutGuide })
            holder = current.superview
        }
        layoutGuides.removeAll { $0 === layoutGuide }
        layoutGuide.owningView = nil
        irisRootView.layoutEngine?.setNeedsSync()
    }

    /// The bounds inside the safe area.
    open private(set) lazy var safeAreaLayoutGuide = UILayoutGuide(.safeArea, of: self, identifier: "UIViewSafeAreaLayoutGuide")

    /// The bounds inside the layout margins.
    open private(set) lazy var layoutMarginsGuide = UILayoutGuide(.margins, of: self, identifier: "UIViewLayoutMarginsGuide")

    /// The margins guide, no wider than lines of text read well.
    open private(set) lazy var readableContentGuide = UILayoutGuide(.readableContent, of: self, identifier: "UIViewReadableContentGuide")

    /// Above the keyboard.
    open private(set) lazy var keyboardLayoutGuide = UIKeyboardLayoutGuide(.keyboard, of: self, identifier: "UIViewKeyboardLayoutGuide")

    private var ownMargins: UIEdgeInsets?

    /// The space inside the view's edges for its content, which `layoutMarginsGuide` is in:
    /// 8 points, or for a view controller's view its system minimum (none at the top and
    /// bottom, 16 points at the sides); inside the safe area unless
    /// `insetsLayoutMarginsFromSafeArea` is false, and at least the superview's where
    /// `preservesSuperviewLayoutMargins` says.
    open var layoutMargins: UIEdgeInsets {
        get {
            var margins = ownMargins ?? (viewController == nil ? UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8) : .zero)
            if let viewController, viewController.viewRespectsSystemMinimumLayoutMargins {
                let minimum = viewController.systemMinimumLayoutMargins
                margins = UIEdgeInsets(
                    top: max(margins.top, minimum.top), left: max(margins.left, minimum.leading),
                    bottom: max(margins.bottom, minimum.bottom), right: max(margins.right, minimum.trailing)
                )
            }
            if insetsLayoutMarginsFromSafeArea {
                let safe = safeAreaInsets
                margins = UIEdgeInsets(top: margins.top + safe.top, left: margins.left + safe.left, bottom: margins.bottom + safe.bottom, right: margins.right + safe.right)
            }
            if preservesSuperviewLayoutMargins, let superview {
                let outer = superview.layoutMargins, frame = frame, size = superview.bounds.size
                margins = UIEdgeInsets(
                    top: max(margins.top, outer.top - frame.minY), left: max(margins.left, outer.left - frame.minX),
                    bottom: max(margins.bottom, outer.bottom - (size.height - frame.maxY)), right: max(margins.right, outer.right - (size.width - frame.maxX))
                )
            }
            return margins
        }
        set {
            ownMargins = newValue
            layoutMarginsDidChange()
            LayerCommit.schedule()
        }
    }

    open var directionalLayoutMargins: NSDirectionalEdgeInsets {
        get {
            let margins = layoutMargins
            return NSDirectionalEdgeInsets(top: margins.top, leading: margins.left, bottom: margins.bottom, trailing: margins.right)
        }
        set {
            layoutMargins = UIEdgeInsets(top: newValue.top, left: newValue.leading, bottom: newValue.bottom, right: newValue.trailing)
        }
    }

    open var preservesSuperviewLayoutMargins = false {
        didSet { LayerCommit.schedule() }
    }

    open var insetsLayoutMarginsFromSafeArea = true {
        didSet { LayerCommit.schedule() }
    }

    open func layoutMarginsDidChange() {}

    /// The view lays out its subviews, between its view controller's callbacks, as in UIKit.
    open func layoutSublayers(of layer: CALayer) {
        if layer === self.layer {
            viewController?.viewWillLayoutSubviews()
            layoutSubviews()
            viewController?.viewDidLayoutSubviews()
        }
    }
}

extension UIView: @preconcurrency CALayerDelegate {}

/// Iris: the layer of a `layerClass`. Swift can't make an instance of a class it knows only
/// at run time without a `required init()`, so other layer classes need a factory
/// (`_IrisInstantiable`).
// ponytail: an app's own layer classes get a plain CALayer; irisrun-ios-build can write their
// factories once OpenUIKit's own layer classes (CAShapeLayer, CAGradientLayer) come.
@MainActor
private func makeLayer(of layerClass: AnyClass) -> CALayer {
    if layerClass != CALayer.self, let layer = instantiate(layerClass) as? CALayer {
        return layer
    }
    return CALayer()
}

extension UIView {
    /// How a view changes when its superview's size does.
    public struct AutoresizingMask: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let flexibleLeftMargin = AutoresizingMask(rawValue: 1 << 0)
        public static let flexibleWidth = AutoresizingMask(rawValue: 1 << 1)
        public static let flexibleRightMargin = AutoresizingMask(rawValue: 1 << 2)
        public static let flexibleTopMargin = AutoresizingMask(rawValue: 1 << 3)
        public static let flexibleHeight = AutoresizingMask(rawValue: 1 << 4)
        public static let flexibleBottomMargin = AutoresizingMask(rawValue: 1 << 5)

        /// A subview's frame after its superview went from `oldSize` to `newSize`: along each
        /// axis, the change is shared among the flexible margins and size in proportion to
        /// their current lengths, or evenly when they are all zero, as UIKit does.
        func resizing(_ frame: CGRect, from oldSize: CGSize, to newSize: CGSize) -> CGRect {
            let (x, width) = Self.resize(
                frame.minX, frame.width, in: oldSize.width, to: newSize.width,
                contains(.flexibleLeftMargin), contains(.flexibleWidth), contains(.flexibleRightMargin)
            )
            let (y, height) = Self.resize(
                frame.minY, frame.height, in: oldSize.height, to: newSize.height,
                contains(.flexibleTopMargin), contains(.flexibleHeight), contains(.flexibleBottomMargin)
            )
            return CGRect(x: x, y: y, width: width, height: height)
        }

        private static func resize(
            _ start: CGFloat, _ length: CGFloat, in oldSize: CGFloat, to newSize: CGFloat,
            _ flexibleStart: Bool, _ flexibleLength: Bool, _ flexibleEnd: Bool
        ) -> (CGFloat, CGFloat) {
            let parts = [(flexibleStart, start), (flexibleLength, length), (flexibleEnd, oldSize - start - length)]
                .filter(\.0).map(\.1)
            let delta = newSize - oldSize
            guard !parts.isEmpty, delta != 0 else { return (start, length) }
            let total = parts.reduce(0, +)
            let share = { (part: CGFloat) in total == 0 ? delta / CGFloat(parts.count) : delta * part / total }
            return (
                flexibleStart ? start + share(start) : start,
                flexibleLength ? max(length + share(length), 0) : length
            )
        }
    }

    public enum ContentMode: Int, Sendable {
        case scaleToFill = 0, scaleAspectFit, scaleAspectFill, redraw
        case center, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight

        /// The layer gravity UIKit sets for the mode; gravities name top and bottom the other
        /// way round (`CALayerContentsGravity.contentMode`).
        var contentsGravity: CALayerContentsGravity {
            switch self {
            case .scaleToFill, .redraw: .resize
            case .scaleAspectFit: .resizeAspect
            case .scaleAspectFill: .resizeAspectFill
            case .center: .center
            case .top: .bottom
            case .bottom: .top
            case .left: .left
            case .right: .right
            case .topLeft: .bottomLeft
            case .topRight: .bottomRight
            case .bottomLeft: .topLeft
            case .bottomRight: .topRight
            }
        }

        /// Where content of `size` goes in `bounds`, as the render core places images.
        func rect(for size: CGSize, in bounds: CGRect) -> CGRect {
            let fit = { (scale: CGFloat) in
                CGRect(x: bounds.midX - size.width * scale / 2, y: bounds.midY - size.height * scale / 2, width: size.width * scale, height: size.height * scale)
            }
            let (sx, sy) = (size.width > 0 ? bounds.width / size.width : 1, size.height > 0 ? bounds.height / size.height : 1)
            // Fractions of the spare room to the left and above.
            let (x, y): (CGFloat, CGFloat)
            switch self {
            case .scaleToFill, .redraw: return bounds
            case .scaleAspectFit: return fit(min(sx, sy))
            case .scaleAspectFill: return fit(max(sx, sy))
            case .center: (x, y) = (0.5, 0.5)
            case .top: (x, y) = (0.5, 0)
            case .bottom: (x, y) = (0.5, 1)
            case .left: (x, y) = (0, 0.5)
            case .right: (x, y) = (1, 0.5)
            case .topLeft: (x, y) = (0, 0)
            case .topRight: (x, y) = (1, 0)
            case .bottomLeft: (x, y) = (0, 1)
            case .bottomRight: (x, y) = (1, 1)
            }
            return CGRect(x: bounds.minX + (bounds.width - size.width) * x, y: bounds.minY + (bounds.height - size.height) * y, width: size.width, height: size.height)
        }
    }

    public enum TintAdjustmentMode: Int, Sendable {
        case automatic = 0, normal, dimmed
    }
}

// MARK: Animations

extension UIView {
    /// Animates the changes `animations` makes to frames, transforms, alpha and background
    /// colors of views, also the frames a `layoutIfNeeded()` in it sets, from what shows to the
    /// new values, which views take at once, as in UIKit. `completion` runs once the animation
    /// is over: on a device after its delay and duration (never for one that repeats); in a
    /// script, which shows where animations end, on the main queue's next turn.
    // ponytail: `finished` is always true; no beginFromCurrentState (an animation starts from
    // the last value drawn), no user interaction rules, and an arranged view hides at once
    // rather than at the end; the rest of UIView's animation API comes with step 4.
    public class func animate(
        withDuration duration: TimeInterval, delay: TimeInterval, options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil
    ) {
        animate(IrisAnimationTiming(duration: duration, delay: delay, options: options), animations: animations, completion: completion)
    }

    public class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        animate(withDuration: duration, delay: 0, options: [], animations: animations, completion: completion)
    }

    public class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void) {
        animate(withDuration: duration, delay: 0, options: [], animations: animations, completion: nil)
    }

    /// As a spring that settles in `duration`.
    // ponytail: an ease-out curve, without the spring's overshoot or initial velocity; a spring
    // timing in the render core if apps show the difference.
    public class func animate(
        withDuration duration: TimeInterval, delay: TimeInterval, usingSpringWithDamping dampingRatio: CGFloat,
        initialSpringVelocity velocity: CGFloat, options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil
    ) {
        animate(IrisAnimationTiming(duration: duration, delay: delay, options: options, spring: true), animations: animations, completion: completion)
    }

    /// Runs `actionsWithoutAnimation` without animating what it changes, even in an animation.
    public class func performWithoutAnimation(_ actionsWithoutAnimation: () -> Void) {
        let outer = IrisAnimationTiming.current
        IrisAnimationTiming.current = nil
        defer { IrisAnimationTiming.current = outer }
        actionsWithoutAnimation()
    }

    private class func animate(_ timing: IrisAnimationTiming, animations: () -> Void, completion: ((Bool) -> Void)?) {
        let outer = IrisAnimationTiming.current
        IrisAnimationTiming.current = timing.duration > 0 ? timing : nil
        animations()
        IrisAnimationTiming.current = outer
        guard let completion, timing.repeatCount < .infinity else { return }
        nonisolated(unsafe) let unsafeCompletion = completion
        let finish: @Sendable () -> Void = { MainActor.assumeIsolated { unsafeCompletion(true) } }
        if irisAnimates, timing.duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.delay + timing.duration * (timing.autoreverses ? 2 : 1), execute: finish)
        } else {
            DispatchQueue.main.async(execute: finish)
        }
    }

    /// How an animation runs: its curve, whether it repeats, and what UIKit lets happen while it does.
    public struct AnimationOptions: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let layoutSubviews = AnimationOptions(rawValue: 1 << 0)
        public static let allowUserInteraction = AnimationOptions(rawValue: 1 << 1)
        public static let beginFromCurrentState = AnimationOptions(rawValue: 1 << 2)
        public static let `repeat` = AnimationOptions(rawValue: 1 << 3)
        public static let autoreverse = AnimationOptions(rawValue: 1 << 4)
        public static let overrideInheritedDuration = AnimationOptions(rawValue: 1 << 5)
        public static let overrideInheritedCurve = AnimationOptions(rawValue: 1 << 6)
        public static let allowAnimatedContent = AnimationOptions(rawValue: 1 << 7)
        public static let showHideTransitionViews = AnimationOptions(rawValue: 1 << 8)
        public static let overrideInheritedOptions = AnimationOptions(rawValue: 1 << 9)
        public static let curveEaseInOut = AnimationOptions(rawValue: 0 << 16)
        public static let curveEaseIn = AnimationOptions(rawValue: 1 << 16)
        public static let curveEaseOut = AnimationOptions(rawValue: 2 << 16)
        public static let curveLinear = AnimationOptions(rawValue: 3 << 16)
    }
}

// MARK: Anchors

extension UIView {
    open var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .leading) }
    open var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .trailing) }
    open var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .left) }
    open var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .right) }
    open var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .top) }
    open var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .bottom) }
    open var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .width) }
    open var heightAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .height) }
    open var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .centerX) }
    open var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .centerY) }
    /// The baselines of the view's text, from its font; a view without text's are its bottom.
    open var firstBaselineAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .firstBaseline) }
    open var lastBaselineAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .lastBaseline) }
}
