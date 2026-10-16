import Foundation

/// Recognizes a gesture in the touches of a view and the views inside it, and sends its
/// actions as the gesture goes on. Windows give touches to recognizers before views; one that
/// recognizes cancels the touches it saw in their views (`cancelsTouchesInView`). Subclasses
/// set `state` from the touches they get; a recognizer leaving `.possible` first waits for the
/// recognizers it requires to fail, and fails if an active one prevents it.
@preconcurrency @MainActor
open class UIGestureRecognizer: NSObject {
    public init(target: Any?, action: Selector?) {
        super.init()
        if let target, let action {
            addTarget(target, action: action)
        }
    }

    public override convenience init() {
        self.init(target: nil, action: nil)
    }

    // MARK: Targets and actions

    private struct TargetAction {
        weak var target: AnyObject?
        var action: Selector
    }

    private var targetActions: [TargetAction] = []

    /// Adds an action to send to `target`, which the recognizer doesn't keep; adding a pair
    /// again does nothing.
    open func addTarget(_ target: Any, action: Selector) {
        let target = target as AnyObject
        guard !targetActions.contains(where: { $0.target === target && $0.action == action }) else { return }
        targetActions.append(TargetAction(target: target, action: action))
    }

    /// Removes the pairs with this target and action; nil matches any.
    open func removeTarget(_ target: Any?, action: Selector?) {
        let target = target.map { $0 as AnyObject }
        targetActions.removeAll { pair in
            (target == nil || pair.target === target) && (action == nil || pair.action == action)
        }
    }

    /// Sends the actions with the recognizer as their sender, as each change of state does.
    func sendActions() {
        for pair in targetActions {
            if let target = pair.target {
                _IrisMethods.send(pair.action, to: target, with: [self])
            }
        }
    }

    // MARK: State

    /// Settable by subclasses, as `UIGestureRecognizerSubclass` makes it on iOS.
    open var state: UIGestureRecognizer.State {
        get { current }
        set { request(newValue) }
    }

    /// The state apps see.
    var current = State.possible
    /// `.began` or `.ended`, asked for while `.possible`, until `GestureEnvironment` lets it.
    var requested: State?
    /// The state changed after the gesture began; the actions go at the next settling.
    var actionsDue = false

    private func request(_ state: State) {
        switch (current, state) {
        case (.possible, .began), (.possible, .ended):
            if requested != .ended {
                requested = state
            }
        case (.possible, .failed), (.possible, .cancelled):
            requested = nil
            current = .failed
        case (.began, .changed), (.began, .ended), (.began, .cancelled),
             (.changed, .changed), (.changed, .ended), (.changed, .cancelled):
            current = state
            actionsDue = true
        case (.began, .failed), (.changed, .failed):
            current = .cancelled
            actionsDue = true
        default:
            // Finished recognizers wait for their reset; other jumps would be a subclass's bug.
            return
        }
        GestureEnvironment.stateDidChange()
    }

    /// Began, changed or ended: the recognizer recognized its gesture.
    var hasRecognized: Bool {
        current == .began || current == .changed || current == .ended
    }

    /// Disabling a recognizer cancels its gesture, or fails it if it hadn't begun.
    open var isEnabled = true {
        didSet {
            if oldValue, !isEnabled, current != .possible || requested != nil || !touches.isEmpty {
                state = current == .possible ? .failed : .cancelled
            }
        }
    }

    /// The view the recognizer is attached to.
    open internal(set) weak var view: UIView?

    open weak var delegate: (any UIGestureRecognizerDelegate)?

    open var cancelsTouchesInView = true
    /// Holds back `touchesBegan` from the view until the recognizer fails.
    open var delaysTouchesBegan = false
    /// Holds back `touchesEnded` from the view until the recognizer fails or recognizes.
    open var delaysTouchesEnded = true
    open var name: String?

    // MARK: Relations

    private struct WeakRecognizer {
        weak var recognizer: UIGestureRecognizer?
    }

    private var requiredToFail: [WeakRecognizer] = []

    /// Waits for `otherGestureRecognizer` to fail before recognizing, and fails if it recognizes.
    open func require(toFail otherGestureRecognizer: UIGestureRecognizer) {
        requiredToFail.append(WeakRecognizer(recognizer: otherGestureRecognizer))
    }

    /// Whether this recognizer waits for `other` to fail: required with `require(toFail:)`, by
    /// either recognizer's class, or by either one's delegate.
    func waits(for other: UIGestureRecognizer) -> Bool {
        requiredToFail.contains { $0.recognizer === other }
            || shouldRequireFailure(of: other) || other.shouldBeRequiredToFail(by: self)
            || delegate?.gestureRecognizer(self, shouldRequireFailureOf: other) == true
            || other.delegate?.gestureRecognizer(other, shouldBeRequiredToFailBy: self) == true
    }

    /// Whether this recognizer, recognizing, makes `other` fail: unless either delegate lets
    /// them recognize together, and if their classes agree.
    func prevents(_ other: UIGestureRecognizer) -> Bool {
        delegate?.gestureRecognizer(self, shouldRecognizeSimultaneouslyWith: other) != true
            && other.delegate?.gestureRecognizer(other, shouldRecognizeSimultaneouslyWith: self) != true
            && canPrevent(other) && other.canBePrevented(by: self)
    }

    // MARK: Touches

    /// The touches the recognizer follows, in the order they began; lifted ones leave after
    /// the event they lifted in.
    var touches: [UITouch] = []
    /// Where the touches were, in the window's coordinates, for once they have lifted.
    var lastLocation: CGPoint?

    /// More touches may come that the recognizer counts on, as for a second tap.
    var awaitsTouches: Bool {
        false
    }

    open var numberOfTouches: Int {
        touches.count
    }

    /// The centroid of the touches, or where they were last.
    open func location(in view: UIView?) -> CGPoint {
        point(centroid ?? .zero, in: view)
    }

    open func location(ofTouch touchIndex: Int, in view: UIView?) -> CGPoint {
        guard touches.indices.contains(touchIndex) else {
            fatalError("-[\(type(of: self)) locationOfTouch:inView:]: index (\(touchIndex)) beyond bounds (\(touches.count)).")
        }
        return touches[touchIndex].location(in: view)
    }

    /// In the window's coordinates.
    var centroid: CGPoint? {
        guard !touches.isEmpty else { return lastLocation }
        let sum = touches.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.location.x, y: $0.y + $1.location.y) }
        return CGPoint(x: sum.x / CGFloat(touches.count), y: sum.y / CGFloat(touches.count))
    }

    /// A point in the window's coordinates, in `view`'s.
    func point(_ point: CGPoint, in view: UIView?) -> CGPoint {
        guard let view, let window = self.view?.window else { return point }
        return view.convert(point, from: window)
    }

    // MARK: For subclasses

    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {}

    /// Called when the recognizer starts over, after it finished.
    open func reset() {}

    /// Stops following a touch.
    open func ignore(_ touch: UITouch, for event: UIEvent) {
        touches.removeAll { $0 === touch }
        touch.recognizers.removeAll { $0 === self }
    }

    open func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    open func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    open func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    open func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

extension UIGestureRecognizer {
    public enum State: Int, Sendable {
        case possible = 0, began, changed, ended, cancelled, failed

        public static let recognized = State.ended
    }
}

/// What a recognizer asks before it takes touches or recognizes. Every method is optional.
@preconcurrency @MainActor
public protocol UIGestureRecognizerDelegate: NSObjectProtocol {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool
}

extension UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        true
    }
}

// MARK: - Delivery

/// Iris: what UIKit's gesture environment does for windows. It picks the recognizers each touch
/// goes to, gives them the touches before the views, settles which recognizers recognize, and
/// gives views the touch phases that no recognizer holds back or took.
@MainActor
enum GestureEnvironment {
    /// Touches still down, or with phases held back from their view.
    private static var touches: [UITouch] = []
    /// Recognizers with touches, or still deciding after their touches lifted.
    private static var recognizers: [UIGestureRecognizer] = []
    private static var event: UIEvent?
    private static var isDelivering = false
    private static var isSettleScheduled = false

    /// Delivers the touches of an event in one window.
    static func deliver(_ eventTouches: Set<UITouch>, with event: UIEvent) {
        self.event = event
        isDelivering = true
        defer { isDelivering = false }
        let ordered = eventTouches.sorted { $0.number < $1.number }
        for touch in ordered where touch.phase == .began {
            begin(touch, with: event)
        }

        // Recognizers first, a call per phase; one waiting to begin goes on getting touches.
        for recognizer in recognizers where recognizer.isEnabled {
            for phase in [UITouch.Phase.began, .moved, .ended, .cancelled] {
                guard recognizer.current == .possible || recognizer.current == .began || recognizer.current == .changed else { break }
                let phaseTouches = ordered.filter { $0.phase == phase && $0.recognizers.contains(recognizer) }
                guard !phaseTouches.isEmpty else { continue }
                let set = Set(phaseTouches)
                switch phase {
                case .began:
                    recognizer.touches += phaseTouches
                    recognizer.touchesBegan(set, with: event)
                case .moved: recognizer.touchesMoved(set, with: event)
                case .ended: recognizer.touchesEnded(set, with: event)
                default: recognizer.touchesCancelled(set, with: event)
                }
            }
        }
        settleRecognizers()

        // Then views, unless a recognizer holds a phase back.
        for touch in ordered where touch.isDelivered && touch.reachesView {
            switch touch.phase {
            case .began, .ended, .cancelled:
                touch.heldPhases.append(touch.phase)
            case .moved where touch.viewBegan && !touch.viewFinished:
                touch.heldPhases.append(.moved)
            default:
                break
            }
        }
        flushViews()
        finish()
    }

    /// Finds the recognizers of a new touch: the view's, then its superviews', up to the window.
    private static func begin(_ touch: UITouch, with event: UIEvent) {
        let down = touches.filter { !$0.hasLifted && $0.isDelivered }
        if let view = touch.view {
            // A view with exclusive touch shares the window with no other finger.
            touch.isDelivered = !down.contains { $0.view !== view && ($0.view?.isExclusiveTouch == true || view.isExclusiveTouch) }
            touch.reachesView = view.isMultipleTouchEnabled || !down.contains { $0.view === view }
        } else {
            touch.isDelivered = false
        }
        touches.append(touch)
        guard touch.isDelivered else { return }
        var view = touch.view
        while let current = view {
            for recognizer in current.gestureRecognizers ?? []
            where recognizer.isEnabled && recognizer.requested == nil
                && (recognizer.current == .possible || recognizer.current == .began || recognizer.current == .changed)
                && recognizer.delegate?.gestureRecognizer(recognizer, shouldReceive: event) != false
                && recognizer.delegate?.gestureRecognizer(recognizer, shouldReceive: touch) != false {
                touch.recognizers.append(recognizer)
                if !recognizers.contains(recognizer) {
                    recognizers.append(recognizer)
                }
            }
            view = current.superview
        }
    }

    /// A recognizer changed state outside touch delivery, as on a timer: settle at the end of
    /// the run loop's turn.
    static func stateDidChange() {
        guard !isDelivering, !isSettleScheduled else { return }
        isSettleScheduled = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated(settle)
        }
    }

    /// Settles the recognizers and gives views what they now may have.
    static func settle() {
        isSettleScheduled = false
        settleRecognizers()
        flushViews()
        finish()
    }

    // MARK: Recognizing

    /// Lets recognizers that asked to leave `.possible` do so, until nothing changes, and sends
    /// the actions of each change, in the order the recognizers got touches.
    static func settleRecognizers() {
        var changed = true
        while changed {
            changed = false
            for recognizer in recognizers {
                if let state = recognizer.requested, recognizer.current == .possible {
                    switch decision(for: recognizer) {
                    case .wait:
                        continue
                    case .fail:
                        recognizer.requested = nil
                        recognizer.current = .failed
                    case .recognize:
                        recognizer.requested = nil
                        recognize(recognizer, as: state)
                    }
                    changed = true
                } else if recognizer.actionsDue {
                    recognizer.actionsDue = false
                    recognizer.sendActions()
                }
            }
        }
    }

    private enum Decision {
        case wait, fail, recognize
    }

    private static func decision(for recognizer: UIGestureRecognizer) -> Decision {
        let others = recognizers.filter { $0 !== recognizer }
        let awaited = others.filter { recognizer.waits(for: $0) }
        if awaited.contains(where: \.hasRecognized) {
            return .fail
        }
        if awaited.contains(where: { $0.current == .possible }) {
            return .wait
        }
        // One that recognized first keeps its touches.
        if others.contains(where: { $0.hasRecognized && share($0, recognizer) && $0.prevents(recognizer) }) {
            return .fail
        }
        guard recognizer.delegate?.gestureRecognizerShouldBegin(recognizer) ?? true, viewsLetBegin(recognizer) else {
            return .fail
        }
        return .recognize
    }

    /// The views under the recognizer's touches, up to its own view, all let it begin: a
    /// control keeps a single tap that would start its own action.
    private static func viewsLetBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        var views: [UIView] = recognizer.view.map { [$0] } ?? []
        for touch in touches where touch.recognizers.contains(recognizer) {
            var view = touch.view
            while let current = view, current !== recognizer.view {
                if !views.contains(current) {
                    views.append(current)
                }
                view = current.superview
            }
        }
        return views.allSatisfy { $0.gestureRecognizerShouldBegin(recognizer) }
    }

    private static func share(_ a: UIGestureRecognizer, _ b: UIGestureRecognizer) -> Bool {
        touches.contains { $0.recognizers.contains(a) && $0.recognizers.contains(b) }
    }

    /// The recognizer recognized: it takes its touches from their views, and the recognizers
    /// it prevents fail.
    private static func recognize(_ recognizer: UIGestureRecognizer, as state: UIGestureRecognizer.State) {
        recognizer.current = state
        if recognizer.cancelsTouchesInView {
            for touch in touches where touch.recognizers.contains(recognizer) {
                touch.isClaimed = true
            }
        }
        for other in recognizers where other !== recognizer && other.current == .possible
            && share(recognizer, other) && recognizer.prevents(other) {
            other.requested = nil
            other.current = .failed
        }
        recognizer.sendActions()
    }

    // MARK: Views and cleanup

    /// Gives views the phases of their touches that no undecided recognizer holds back, a call
    /// per view and phase, and `touchesCancelled` for touches a recognizer took.
    private static func flushViews() {
        var calls: [(view: UIView, phase: UITouch.Phase, touches: [UITouch])] = []
        func add(_ touch: UITouch, _ phase: UITouch.Phase) {
            guard let view = touch.view else { return }
            if let index = calls.firstIndex(where: { $0.view === view && $0.phase == phase }) {
                calls[index].touches.append(touch)
            } else {
                calls.append((view, phase, [touch]))
            }
        }
        for touch in touches {
            if touch.isClaimed {
                touch.heldPhases = []
                if touch.viewBegan, !touch.viewFinished {
                    touch.viewFinished = true
                    add(touch, .cancelled)
                }
                continue
            }
            while let phase = touch.heldPhases.first {
                let undecided = touch.recognizers.filter { $0.current == .possible }
                if phase == .began, undecided.contains(where: \.delaysTouchesBegan) { break }
                if phase == .ended, undecided.contains(where: \.delaysTouchesEnded) { break }
                touch.heldPhases.removeFirst()
                guard phase == .began || (touch.viewBegan && !touch.viewFinished) else { continue }
                touch.viewBegan = true
                touch.viewFinished = phase == .ended || phase == .cancelled
                add(touch, phase)
            }
        }
        guard let event else { return }
        for call in calls {
            let set = Set(call.touches)
            switch call.phase {
            case .began: call.view.touchesBegan(set, with: event)
            case .moved: call.view.touchesMoved(set, with: event)
            case .ended: call.view.touchesEnded(set, with: event)
            default: call.view.touchesCancelled(set, with: event)
            }
        }
    }

    /// Recognizers that finished start over, as do ones whose touches all lifted without them
    /// deciding or waiting for more; lifted touches leave.
    private static func finish() {
        var resetAny = false
        for recognizer in recognizers {
            if recognizer.touches.contains(where: \.hasLifted) {
                recognizer.lastLocation = recognizer.centroid
                recognizer.touches.removeAll(where: \.hasLifted)
            }
            let finished = recognizer.current == .ended || recognizer.current == .cancelled || recognizer.current == .failed
            let idle = recognizer.current == .possible && recognizer.requested == nil && recognizer.touches.isEmpty && !recognizer.awaitsTouches
            if finished || idle {
                reset(recognizer)
                resetAny = true
            }
        }
        if resetAny {
            // Phases they held back can go now.
            flushViews()
        }
        touches.removeAll { $0.hasLifted && $0.heldPhases.isEmpty }
    }

    private static func reset(_ recognizer: UIGestureRecognizer) {
        recognizer.reset()
        recognizer.current = .possible
        recognizer.requested = nil
        recognizer.actionsDue = false
        recognizer.touches = []
        for touch in touches {
            touch.recognizers.removeAll { $0 === recognizer }
        }
        recognizers.removeAll { $0 === recognizer }
    }
}
