import Foundation

/// A view that turns touches into control events, such as `touchUpInside`, and sends the
/// actions registered for them: target-action pairs and `UIAction`s, in the order they were
/// added. It tracks one touch at a time, which counts as inside up to `touchSlop` points
/// outside the bounds, as on iOS.
@preconcurrency @MainActor
open class UIControl: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public convenience init(frame: CGRect, primaryAction: UIAction?) {
        self.init(frame: frame)
        if let primaryAction {
            addAction(primaryAction, for: .primaryActionTriggered)
        }
    }

    // MARK: State

    /// A disabled control tracks no touches and sends no touch events.
    open var isEnabled = true {
        didSet {
            if !isEnabled, isTracking {
                isTracking = false
                isHighlighted = false
                cancelTracking(with: nil)
            }
        }
    }

    open var isSelected = false
    open var isHighlighted = false

    open var state: UIControl.State {
        var state = UIControl.State.normal
        if isHighlighted { state.insert(.highlighted) }
        if !isEnabled { state.insert(.disabled) }
        if isSelected { state.insert(.selected) }
        return state
    }

    open private(set) var isTracking = false
    open private(set) var isTouchInside = false

    /// Points outside the bounds that a tracked touch still counts as inside.
    static let touchSlop: CGFloat = 70

    // MARK: Tracking

    open func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        true
    }

    open func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        true
    }

    open func endTracking(_ touch: UITouch?, with event: UIEvent?) {}

    open func cancelTracking(with event: UIEvent?) {}

    private func isInside(_ touch: UITouch) -> Bool {
        bounds.insetBy(dx: -Self.touchSlop, dy: -Self.touchSlop).contains(touch.location(in: self))
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else {
            return super.touchesBegan(touches, with: event)
        }
        isTouchInside = true
        isTracking = beginTracking(touch, with: event)
        isHighlighted = true
        if isTracking {
            sendActions(for: touch.tapCount > 1 ? [.touchDown, .touchDownRepeat] : .touchDown, with: event)
        }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else {
            return super.touchesMoved(touches, with: event)
        }
        let wasInside = isTouchInside
        isTouchInside = isInside(touch)
        isHighlighted = isTouchInside
        guard isTracking else { return }
        isTracking = continueTracking(touch, with: event)
        guard isTracking else { return }
        var events: Event = isTouchInside ? .touchDragInside : .touchDragOutside
        if isTouchInside != wasInside {
            events.insert(isTouchInside ? .touchDragEnter : .touchDragExit)
        }
        sendActions(for: events, with: event)
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else {
            return super.touchesEnded(touches, with: event)
        }
        isTouchInside = isInside(touch)
        isHighlighted = false
        if isTracking {
            endTracking(touch, with: event)
            sendActions(for: isTouchInside ? touchUpInsideEvents() : .touchUpOutside, with: event)
        }
        isTracking = false
        isTouchInside = false
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else {
            return super.touchesCancelled(touches, with: event)
        }
        isHighlighted = false
        if isTracking {
            cancelTracking(with: event)
            sendActions(for: .touchCancel, with: event)
        }
        isTracking = false
        isTouchInside = false
    }

    /// Iris: the events a touch that lifts inside sends, as it lifts; buttons add their
    /// primary action.
    func touchUpInsideEvents() -> Event {
        .touchUpInside
    }

    // MARK: Content

    open var contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.center {
        didSet { setNeedsLayout() }
    }

    open var contentVerticalAlignment = UIControl.ContentVerticalAlignment.center {
        didSet { setNeedsLayout() }
    }

    /// Leading and trailing as left and right, in a left-to-right layout.
    open var effectiveContentHorizontalAlignment: UIControl.ContentHorizontalAlignment {
        switch contentHorizontalAlignment {
        case .leading: .left
        case .trailing: .right
        case let alignment: alignment
        }
    }

    /// A tap recognizer of a superview doesn't take a single tap from a control that handles
    /// taps, as UIKit's controls keep their default action (iOS 6 and later).
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view !== self, isEnabled, let tap = gestureRecognizer as? UITapGestureRecognizer,
           tap.numberOfTapsRequired == 1, tap.numberOfTouchesRequired == 1,
           !allControlEvents.isDisjoint(with: [.touchDown, .touchUpInside, .primaryActionTriggered]) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    // MARK: Targets and actions

    private struct Handler {
        /// Nil sends the action up the responder chain.
        weak var target: AnyObject?
        var hasTarget: Bool
        var action: Selector?
        var uiAction: UIAction?
        var events: Event
    }

    private var handlers: [Handler] = []

    /// Sends `action` to `target` for these events; a nil target sends it to the first
    /// responder that can perform it. The control doesn't keep the target.
    open func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        let target = target.map { $0 as AnyObject }
        guard !handlers.contains(where: { $0.uiAction == nil && $0.hasTarget == (target != nil) && $0.target === target && $0.action == action && $0.events == controlEvents }) else {
            return
        }
        handlers.append(Handler(target: target, hasTarget: target != nil, action: action, events: controlEvents))
    }

    /// Stops sending `action` to `target` for these events; nil matches any target or action.
    open func removeTarget(_ target: Any?, action: Selector?, for controlEvents: UIControl.Event) {
        let target = target.map { $0 as AnyObject }
        remove(controlEvents) { $0.uiAction == nil && (target == nil || $0.target === target) && (action == nil || $0.action == action) }
    }

    /// Runs `action` for these events, replacing an action with the same identifier.
    open func addAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        removeAction(identifiedBy: action.identifier, for: controlEvents)
        handlers.append(Handler(hasTarget: false, uiAction: action, events: controlEvents))
    }

    open func removeAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        removeAction(identifiedBy: action.identifier, for: controlEvents)
    }

    open func removeAction(identifiedBy actionIdentifier: UIAction.Identifier, for controlEvents: UIControl.Event) {
        remove(controlEvents) { $0.uiAction?.identifier == actionIdentifier }
    }

    private func remove(_ events: Event, where matches: (Handler) -> Bool) {
        for index in handlers.indices.reversed() where matches(handlers[index]) {
            handlers[index].events.subtract(events)
            if handlers[index].events.isEmpty {
                handlers.remove(at: index)
            }
        }
    }

    /// The targets of the target-action pairs; `NSNull` stands for nil.
    open var allTargets: Set<AnyHashable> {
        Set(handlers.compactMap { handler -> AnyHashable? in
            guard handler.uiAction == nil else { return nil }
            guard handler.hasTarget else { return AnyHashable(NSNull()) }
            return handler.target.map { $0 as? AnyHashable ?? AnyHashable(ObjectIdentifier($0)) }
        })
    }

    open var allControlEvents: UIControl.Event {
        handlers.reduce([]) { $0.union($1.events) }
    }

    /// The selectors' names that go to `target` for an event, or nil if none.
    open func actions(forTarget target: Any?, forControlEvent controlEvent: UIControl.Event) -> [String]? {
        let target = target.map { $0 as AnyObject }
        let names = handlers.filter { $0.hasTarget == (target != nil) && $0.target === target && !$0.events.isDisjoint(with: controlEvent) }
            .compactMap { $0.action?.description }
        return names.isEmpty ? nil : names
    }

    open func sendActions(for controlEvents: UIControl.Event) {
        sendActions(for: controlEvents, with: nil)
    }

    /// Sends each action registered for any of the events, once, in the order they were added.
    private func sendActions(for controlEvents: UIControl.Event, with event: UIEvent?) {
        for handler in handlers where !handler.events.isDisjoint(with: controlEvents) {
            if let action = handler.uiAction {
                sendAction(action)
            } else if let action = handler.action, !handler.hasTarget || handler.target != nil {
                sendAction(action, to: handler.target, for: event)
            }
        }
    }

    /// Sends one action through the application; subclasses override it to watch actions.
    open func sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        UIApplication.shared.sendAction(action, to: target, from: self, for: event)
    }

    /// Runs a `UIAction` with this control as its sender.
    open func sendAction(_ action: UIAction) {
        action.sender = self
        action.handler(action)
        action.sender = nil
    }
}

extension UIControl {
    public struct Event: OptionSet, Hashable, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let touchDown = Event(rawValue: 1 << 0)
        public static let touchDownRepeat = Event(rawValue: 1 << 1)
        public static let touchDragInside = Event(rawValue: 1 << 2)
        public static let touchDragOutside = Event(rawValue: 1 << 3)
        public static let touchDragEnter = Event(rawValue: 1 << 4)
        public static let touchDragExit = Event(rawValue: 1 << 5)
        public static let touchUpInside = Event(rawValue: 1 << 6)
        public static let touchUpOutside = Event(rawValue: 1 << 7)
        public static let touchCancel = Event(rawValue: 1 << 8)
        public static let valueChanged = Event(rawValue: 1 << 12)
        public static let primaryActionTriggered = Event(rawValue: 1 << 13)
        public static let menuActionTriggered = Event(rawValue: 1 << 14)
        public static let editingDidBegin = Event(rawValue: 1 << 16)
        public static let editingChanged = Event(rawValue: 1 << 17)
        public static let editingDidEnd = Event(rawValue: 1 << 18)
        public static let editingDidEndOnExit = Event(rawValue: 1 << 19)
        public static let allTouchEvents = Event(rawValue: 0x0000_0FFF)
        public static let allEditingEvents = Event(rawValue: 0x000F_0000)
        public static let applicationReserved = Event(rawValue: 0x0F00_0000)
        public static let systemReserved = Event(rawValue: 0xF000_0000)
        public static let allEvents = Event(rawValue: 0xFFFF_FFFF)
    }

    public enum ContentHorizontalAlignment: Int, Sendable {
        case center = 0, left, right, fill, leading, trailing
    }

    public enum ContentVerticalAlignment: Int, Sendable {
        case center = 0, top, bottom, fill
    }

    public struct State: OptionSet, Hashable, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let normal = State([])
        public static let highlighted = State(rawValue: 1 << 0)
        public static let disabled = State(rawValue: 1 << 1)
        public static let selected = State(rawValue: 1 << 2)
        public static let focused = State(rawValue: 1 << 3)
        public static let application = State(rawValue: 0x00FF_0000)
        public static let reserved = State(rawValue: 0xFF00_0000)
    }
}
