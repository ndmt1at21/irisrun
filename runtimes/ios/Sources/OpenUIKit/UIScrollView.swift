import Foundation
import IrisHost
import IrisRender

/// A view whose content moves under its bounds: the content offset is the bounds' origin. A
/// drag scrolls it, a fling keeps it going and slows as UIKit's does, and past an edge the
/// content stretches and springs back. On a device the motion runs frame by frame, telling the
/// delegate as it goes; a script shows where it ends.
// ponytail: no zooming (pinch, zoomScale, viewForZooming), refresh control, directional lock or
// scroll-to-top; a fling stops at an edge instead of overshooting it, and the offset doesn't
// move when the safe area changes.
@preconcurrency @MainActor
open class UIScrollView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        clipsToBounds = true
        scrollPan.scrollView = self
        addGestureRecognizer(delayRecognizer)
        addGestureRecognizer(scrollPan)
        for indicator in [verticalIndicator, horizontalIndicator] {
            indicator.cornerRadius = 1.5
            indicator.opacity = 0
            layer.addSublayer(indicator)
        }
    }

    open weak var delegate: (any UIScrollViewDelegate)?

    // MARK: Content

    open var contentSize = CGSize.zero {
        didSet {
            _irisDidChangeValue(self, \UIScrollView.contentSize, from: oldValue)
            updateIndicators()
        }
    }

    /// The point of the content at the bounds' top-left corner.
    open var contentOffset: CGPoint {
        get { bounds.origin }
        set { bounds.origin = newValue }
    }

    override open var bounds: CGRect {
        didSet {
            guard bounds.origin != oldValue.origin else { return }
            _irisDidChangeValue(self, \UIScrollView.contentOffset, from: oldValue.origin)
            setNeedsLayout()
            updateIndicators()
            delegate?.scrollViewDidScroll(self)
        }
    }

    open func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        stopScrolling()
        guard animated, contentOffset != self.contentOffset else {
            self.contentOffset = contentOffset
            return
        }
        isScrollAnimating = true
        run(ScrollMotion(from: self.contentOffset, to: contentOffset, kind: .spring)) { [unowned self] in
            isScrollAnimating = false
            delegate?.scrollViewDidEndScrollingAnimation(self)
        }
    }

    /// Scrolls as little as shows the rectangle, of the content, inside the insets.
    open func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        let inset = adjustedContentInset
        func scroll(_ offset: CGFloat, before: CGFloat, length: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
            var offset = offset
            if end > offset + before + length { offset = end - before - length }
            if start < offset + before { offset = start - before }
            return offset
        }
        let offset = clamped(CGPoint(
            x: scroll(contentOffset.x, before: inset.left, length: bounds.width - inset.left - inset.right, start: rect.minX, end: rect.maxX),
            y: scroll(contentOffset.y, before: inset.top, length: bounds.height - inset.top - inset.bottom, start: rect.minY, end: rect.maxY)
        ))
        guard offset != contentOffset else { return }
        setContentOffset(offset, animated: animated)
    }

    open var contentInset = UIEdgeInsets.zero {
        didSet {
            _irisDidChangeValue(self, \UIScrollView.contentInset, from: oldValue)
            adjustedContentInsetDidChange()
        }
    }

    open var contentInsetAdjustmentBehavior = ContentInsetAdjustmentBehavior.automatic {
        didSet { adjustedContentInsetDidChange() }
    }

    open var automaticallyAdjustsScrollIndicatorInsets = true

    /// The content inset with the safe area along the axes it adjusts: those that scroll, for
    /// the automatic behaviors; both, or neither.
    open var adjustedContentInset: UIEdgeInsets {
        let safe = contentInsetAdjustmentBehavior == .never ? .zero : safeAreaInsets
        var inset = contentInset
        let both = contentInsetAdjustmentBehavior == .always
        if both || contentSize.height + contentInset.top + contentInset.bottom > bounds.height || alwaysBounceVertical {
            inset.top += safe.top
            inset.bottom += safe.bottom
        }
        if both || contentSize.width + contentInset.left + contentInset.right > bounds.width || alwaysBounceHorizontal {
            inset.left += safe.left
            inset.right += safe.right
        }
        return inset
    }

    open func adjustedContentInsetDidChange() {
        delegate?.scrollViewDidChangeAdjustedContentInset(self)
    }

    // MARK: Scrolling

    open var isScrollEnabled: Bool {
        get { scrollPan.isEnabled }
        set { scrollPan.isEnabled = newValue }
    }

    /// Stops at multiples of the bounds' size.
    open var isPagingEnabled = false
    open var isDirectionalLockEnabled = false
    open var scrollsToTop = true
    open var bounces = true
    open var alwaysBounceVertical = false
    open var alwaysBounceHorizontal = false
    open var decelerationRate = DecelerationRate.normal
    open var keyboardDismissMode = KeyboardDismissMode.none

    /// Holds a touch back from the content for a moment, so that a drag doesn't press what it
    /// starts on.
    open var delaysContentTouches: Bool {
        get { delayRecognizer.isEnabled }
        set { delayRecognizer.isEnabled = newValue }
    }

    /// Whether a drag may take a touch the content already has, if `touchesShouldCancel(in:)`
    /// lets it.
    open var canCancelContentTouches = true

    // ponytail: not asked; content always gets the touches the scroll view doesn't take.
    open func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        true
    }

    /// Controls keep a touch they have; other views give it up to a drag.
    open func touchesShouldCancel(in view: UIView) -> Bool {
        !(view is UIControl)
    }

    open var panGestureRecognizer: UIPanGestureRecognizer {
        scrollPan
    }

    private let scrollPan = ScrollPanGestureRecognizer()
    private let delayRecognizer = DelayedTouchesRecognizer()

    /// A finger is down on the scroll view.
    open private(set) var isTracking = false
    /// The finger moved the content.
    open private(set) var isDragging = false
    /// Moving on after a drag.
    open private(set) var isDecelerating = false
    private var isScrollAnimating = false
    private var dragStart = CGPoint.zero

    open var isZooming: Bool {
        false
    }

    open var isZoomBouncing: Bool {
        false
    }

    fileprivate func fingerDown() {
        isTracking = true
        stopScrolling()
    }

    fileprivate func fingerUp() {
        isTracking = false
    }

    /// The scroll view's own pan: it moves the content with the finger, then lets it go.
    fileprivate func pan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            stopScrolling()
            dragStart = contentOffset
            isDragging = true
            if keyboardDismissMode == .onDrag || keyboardDismissMode == .onDragWithAccessory {
                window?.endEditing(true)
            }
            delegate?.scrollViewWillBeginDragging(self)
            showIndicators()
            follow(pan)
        case .changed:
            follow(pan)
        case .ended, .cancelled:
            isDragging = false
            isTracking = false
            let finger = pan.state == .ended ? pan.velocity(in: self) : .zero
            let velocity = CGPoint(x: canScrollHorizontally ? -finger.x : 0, y: canScrollVertically ? -finger.y : 0)
            letGo(velocity: velocity)
        default:
            break
        }
    }

    private func follow(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: self)
        let wanted = CGPoint(
            x: dragStart.x - (canScrollHorizontally ? translation.x : 0),
            y: dragStart.y - (canScrollVertically ? translation.y : 0)
        )
        contentOffset = bounces ? stretched(wanted) : clamped(wanted)
    }

    /// After a drag: the delegate may move the target, then the content decelerates to it, or
    /// springs back inside its edges or to a page.
    private func letGo(velocity: CGPoint) {
        let offset = contentOffset
        let isPastEdge = clamped(offset) != offset
        var target: CGPoint
        if isPagingEnabled {
            let page = bounds.size
            target = clamped(CGPoint(
                x: ScrollMotion.page(from: dragStart.x, at: offset.x, velocity: velocity.x, size: page.width),
                y: ScrollMotion.page(from: dragStart.y, at: offset.y, velocity: velocity.y, size: page.height)
            ))
        } else {
            let distance = ScrollMotion.distance(velocity: velocity, rate: decelerationRate.rawValue)
            target = clamped(CGPoint(x: offset.x + distance.x, y: offset.y + distance.y))
        }
        // UIKit gives the velocity in points per millisecond.
        withUnsafeMutablePointer(to: &target) { target in
            delegate?.scrollViewWillEndDragging(self, withVelocity: CGPoint(x: velocity.x / 1000, y: velocity.y / 1000), targetContentOffset: target)
        }
        let willDecelerate = target != offset
        delegate?.scrollViewDidEndDragging(self, willDecelerate: willDecelerate)
        guard willDecelerate else { return hideIndicators() }
        delegate?.scrollViewWillBeginDecelerating(self)
        isDecelerating = true
        let kind: ScrollMotion.Kind = isPastEdge || isPagingEnabled ? .spring : .decelerate(rate: decelerationRate.rawValue)
        run(ScrollMotion(from: offset, to: target, velocity: velocity, kind: kind)) { [unowned self] in
            isDecelerating = false
            delegate?.scrollViewDidEndDecelerating(self)
            hideIndicators()
        }
    }

    /// A drag that would scroll the content along an axis it can't scroll is left to a scroll
    /// view around this one; one on content that already has the touch only starts if the
    /// content gives it up.
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === scrollPan else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        let translation = scrollPan.translation(in: self)
        guard abs(translation.y) >= abs(translation.x) ? canScrollVertically : canScrollHorizontally else { return false }
        for touch in scrollPan.touches where touch.viewBegan && !touch.viewFinished {
            if let view = touch.view, view !== self, !canCancelContentTouches || !touchesShouldCancel(in: view) {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// A touch that stops moving content doesn't reach the content, as in UIKit.
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit != nil && (isDecelerating || isScrollAnimating) ? self : hit
    }

    // MARK: Limits

    private var minimumOffset: CGPoint {
        let inset = adjustedContentInset
        return CGPoint(x: -inset.left, y: -inset.top)
    }

    private var maximumOffset: CGPoint {
        let inset = adjustedContentInset
        return CGPoint(
            x: max(contentSize.width + inset.right - bounds.width, -inset.left),
            y: max(contentSize.height + inset.bottom - bounds.height, -inset.top)
        )
    }

    private var canScrollVertically: Bool {
        maximumOffset.y > minimumOffset.y || alwaysBounceVertical
    }

    private var canScrollHorizontally: Bool {
        maximumOffset.x > minimumOffset.x || alwaysBounceHorizontal
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let (low, high) = (minimumOffset, maximumOffset)
        return CGPoint(x: min(max(point.x, low.x), high.x), y: min(max(point.y, low.y), high.y))
    }

    /// Past an edge, the content follows the finger less and less.
    private func stretched(_ point: CGPoint) -> CGPoint {
        let edge = clamped(point)
        return CGPoint(
            x: edge.x + ScrollMotion.rubberBand(point.x - edge.x, dimension: bounds.width),
            y: edge.y + ScrollMotion.rubberBand(point.y - edge.y, dimension: bounds.height)
        )
    }

    // MARK: Motion

    private var motionTimer: Timer?

    /// Moves the content on its own, a frame at a time on a device; a script jumps to the end.
    // Final: a vtable entry for a private method whose closure is @Sendable and isolated is
    // mangled one way in the class and another in subclasses (Swift 6.4.1), and fails to link.
    private final func run(_ motion: ScrollMotion, completion: @escaping @MainActor @Sendable () -> Void) {
        guard irisAnimates else {
            contentOffset = motion.to
            return completion()
        }
        let start = ProcessInfo.processInfo.systemUptime
        // Foundation on Linux fires Timer(timeInterval:repeats:block:) at once; this one waits.
        let timer = Timer(fire: Date(timeIntervalSinceNow: 1.0 / 60), interval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let (offset, done) = motion.offset(at: ProcessInfo.processInfo.systemUptime - start)
                self.contentOffset = offset
                if done {
                    self.stopScrolling()
                    completion()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
    }

    /// Stops the content where it is, as a touch does.
    private func stopScrolling() {
        motionTimer?.invalidate()
        motionTimer = nil
        isDecelerating = false
        isScrollAnimating = false
    }

    // MARK: Indicators

    open var showsVerticalScrollIndicator = true
    open var showsHorizontalScrollIndicator = true

    open var indicatorStyle = IndicatorStyle.default {
        didSet { updateIndicators() }
    }

    open var verticalScrollIndicatorInsets = UIEdgeInsets.zero
    open var horizontalScrollIndicatorInsets = UIEdgeInsets.zero

    @available(iOS, deprecated: 13.0, message: "Use verticalScrollIndicatorInsets or horizontalScrollIndicatorInsets")
    open var scrollIndicatorInsets: UIEdgeInsets {
        get { verticalScrollIndicatorInsets }
        set {
            verticalScrollIndicatorInsets = newValue
            horizontalScrollIndicatorInsets = newValue
        }
    }

    private let verticalIndicator = CALayer()
    private let horizontalIndicator = CALayer()

    /// Shows the indicators for a moment.
    open func flashScrollIndicators() {
        showIndicators()
        hideIndicators()
    }

    private func showIndicators() {
        updateIndicators()
        verticalIndicator.opacity = showsVerticalScrollIndicator && maximumOffset.y > minimumOffset.y ? 1 : 0
        horizontalIndicator.opacity = showsHorizontalScrollIndicator && maximumOffset.x > minimumOffset.x ? 1 : 0
    }

    /// The indicators fade out once the content stops.
    private func hideIndicators() {
        for indicator in [verticalIndicator, horizontalIndicator] where indicator.opacity > 0 {
            indicator.irisAnimations = [Animation(from: .opacity(indicator.opacity), to: .opacity(0), duration: 0.3)]
            indicator.opacity = 0
        }
    }

    /// Thin bars inside the edges, as long as the share of the content that shows and shorter
    /// past an edge, in the content's coordinates so that they stay put as it moves.
    private func updateIndicators() {
        let color: UIColor = indicatorStyle == .white ? UIColor(white: 1, alpha: 0.35) : UIColor(white: 0, alpha: 0.35)
        let inset = adjustedContentInset
        let (low, high) = (minimumOffset, maximumOffset)
        let (thickness, margin): (CGFloat, CGFloat) = (3, 3)
        func bar(offset: CGFloat, low: CGFloat, high: CGFloat, visible: CGFloat, content: CGFloat, track: CGFloat) -> (start: CGFloat, length: CGFloat) {
            let overshoot = max(low - offset, offset - high, 0)
            let length = max(min(max(36, track * visible / max(content, 1)), track) - overshoot, 7)
            let progress = high > low ? min(max((offset - low) / (high - low), 0), 1) : 0
            return ((track - length) * progress, length)
        }
        let v = verticalScrollIndicatorInsets
        let verticalTrack = bounds.height - inset.top - inset.bottom - v.top - v.bottom - 2 * margin
        let vertical = bar(offset: contentOffset.y, low: low.y, high: high.y, visible: bounds.height, content: contentSize.height + inset.top + inset.bottom, track: verticalTrack)
        verticalIndicator.frame = CGRect(
            x: contentOffset.x + bounds.width - v.right - margin - thickness,
            y: contentOffset.y + inset.top + v.top + margin + vertical.start,
            width: thickness, height: vertical.length
        )
        let h = horizontalScrollIndicatorInsets
        let horizontalTrack = bounds.width - inset.left - inset.right - h.left - h.right - 2 * margin
        let horizontal = bar(offset: contentOffset.x, low: low.x, high: high.x, visible: bounds.width, content: contentSize.width + inset.left + inset.right, track: horizontalTrack)
        horizontalIndicator.frame = CGRect(
            x: contentOffset.x + inset.left + h.left + margin + horizontal.start,
            y: contentOffset.y + bounds.height - h.bottom - margin - thickness,
            width: horizontal.length, height: thickness
        )
        verticalIndicator.backgroundColor = color.cgColor
        horizontalIndicator.backgroundColor = color.cgColor
    }

    /// The indicators stay above the content.
    override open func insertSubview(_ view: UIView, at index: Int) {
        super.insertSubview(view, at: index)
        layer.addSublayer(verticalIndicator)
        layer.addSublayer(horizontalIndicator)
    }
}

extension UIScrollView {
    /// How fast the content slows after a fling: the share of its speed kept each millisecond.
    public struct DecelerationRate: RawRepresentable, Hashable, Sendable {
        public let rawValue: CGFloat

        public init(rawValue: CGFloat) {
            self.rawValue = rawValue
        }

        public static let normal = DecelerationRate(rawValue: 0.998)
        public static let fast = DecelerationRate(rawValue: 0.99)
    }

    public enum ContentInsetAdjustmentBehavior: Int, Sendable {
        case automatic = 0, scrollableAxes, never, always
    }

    public enum IndicatorStyle: Int, Sendable {
        case `default` = 0, black, white
    }

    public enum KeyboardDismissMode: Int, Sendable {
        case none = 0, onDrag, interactive
        case onDragWithAccessory, interactiveWithAccessory
    }
}

/// What a scroll view tells as it scrolls. Every method is optional.
@preconcurrency @MainActor
public protocol UIScrollViewDelegate: NSObjectProtocol {
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView)
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView)
}

extension UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {}
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {}
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {}
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {}
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {}
    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool { true }
    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {}
    public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {}
}

/// Iris: how content moves on its own after a drag, by the numbers of UIScrollView's that are
/// known, as OpenSwiftUI's ScrollView moves (patch 0011): a fling slows by the deceleration
/// rate each millisecond; content past an edge, and paging, settle as a critically damped
/// spring of 0.4 s.
struct ScrollMotion {
    enum Kind {
        case decelerate(rate: CGFloat)
        case spring
    }

    var from: CGPoint
    var to: CGPoint
    /// Points per second, at the start.
    var velocity = CGPoint.zero
    var kind: Kind

    /// How far content goes after a fling at `velocity` points per second.
    static func distance(velocity: CGPoint, rate: CGFloat) -> CGPoint {
        let scale = rate / (1 - rate) / 1000
        return CGPoint(x: velocity.x * scale, y: velocity.y * scale)
    }

    /// UIKit's rubber band: past an edge by `overshoot`, content shows this far past it.
    static func rubberBand(_ overshoot: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0, overshoot != 0 else { return 0 }
        let sign: CGFloat = overshoot < 0 ? -1 : 1
        return sign * (1 - 1 / (abs(overshoot) * 0.55 / dimension + 1)) * dimension
    }

    /// The page a drag that began at `start` ends on: the next one in the direction of a
    /// fling, else the nearest, and never more than one page from where it began.
    static func page(from start: CGFloat, at offset: CGFloat, velocity: CGFloat, size: CGFloat) -> CGFloat {
        guard size > 0 else { return offset }
        let first = (start / size).rounded()
        var page = (offset / size).rounded()
        if velocity > 100 {
            page = (offset / size).rounded(.down) + 1
        } else if velocity < -100 {
            page = (offset / size).rounded(.up) - 1
        }
        return min(max(page, first - 1), first + 1) * size
    }

    /// Where the content is `t` seconds in, and whether it has arrived (within half a point).
    func offset(at t: TimeInterval) -> (CGPoint, Bool) {
        let t = CGFloat(max(t, 0))
        let (dx, dy) = (from.x - to.x, from.y - to.y)
        let (x, y): (CGFloat, CGFloat)
        switch kind {
        case let .decelerate(rate):
            let left = pow(rate, t * 1000)
            (x, y) = (dx * left, dy * left)
        case .spring:
            let omega = 2 * CGFloat.pi / 0.4
            let decay = exp(-omega * t)
            // The velocity is the offset's; the spring's displacement moves the same way.
            (x, y) = ((dx + (velocity.x + omega * dx) * t) * decay, (dy + (velocity.y + omega * dy) * t) * decay)
        }
        let done = abs(x) < 0.5 && abs(y) < 0.5 && t > 0
        return (done ? to : CGPoint(x: to.x + x, y: to.y + y), done)
    }
}

/// Iris: the scroll view's pan, which tells it when a finger touches and lifts, and moves its
/// content before the app's targets hear of each change.
@MainActor
private final class ScrollPanGestureRecognizer: UIPanGestureRecognizer {
    weak var scrollView: UIScrollView?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        scrollView?.fingerDown()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if self.touches.allSatisfy(\.hasLifted), state == .possible || state == .failed {
            scrollView?.fingerUp()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        scrollView?.fingerUp()
    }

    override func sendActions() {
        scrollView?.pan(self)
        super.sendActions()
    }
}

/// Iris: holds touches back from the content for 0.15 s, as UIKit does while
/// `delaysContentTouches` is on, then fails, and the content gets them; a drag that starts
/// sooner takes them instead. A touch that lifts sooner reaches the content as it lifts.
@MainActor
private final class DelayedTouchesRecognizer: UIGestureRecognizer {
    private var timer: Timer?

    init() {
        super.init(target: nil, action: nil)
        delaysTouchesBegan = true
        cancelsTouchesInView = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard timer == nil else { return }
        // Foundation on Linux fires Timer(timeInterval:repeats:block:) at once; this one waits.
        let timer = Timer(fire: Date(timeIntervalSinceNow: 0.15), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.state = .failed
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func reset() {
        timer?.invalidate()
        timer = nil
    }
}
