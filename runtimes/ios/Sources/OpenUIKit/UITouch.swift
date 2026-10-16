import Foundation

/// A finger on the screen, from when it touches to when it lifts. UIKit keeps updating the
/// same object as the finger moves, and the touch stays with the view it began in.
@preconcurrency @MainActor
open class UITouch: NSObject {
    /// When the touch last changed, in seconds on the `systemUptime` clock.
    open internal(set) var timestamp: TimeInterval = 0
    open internal(set) var phase = UITouch.Phase.began
    /// How many times the finger tapped at this spot in a row, counting this touch.
    open internal(set) var tapCount = 1
    open internal(set) var type = UITouch.TouchType.direct
    open internal(set) var window: UIWindow?
    /// The view the touch began in.
    open internal(set) var view: UIView?

    /// The recognizers that get the touch, the view's first, then each superview's.
    open var gestureRecognizers: [UIGestureRecognizer]? {
        recognizers
    }

    /// Where the touch is, and was before its last change, in the window's coordinates.
    var location = CGPoint.zero
    var previousLocation = CGPoint.zero

    open func location(in view: UIView?) -> CGPoint {
        convert(location, to: view)
    }

    open func previousLocation(in view: UIView?) -> CGPoint {
        convert(previousLocation, to: view)
    }

    open func preciseLocation(in view: UIView?) -> CGPoint {
        location(in: view)
    }

    open func precisePreviousLocation(in view: UIView?) -> CGPoint {
        previousLocation(in: view)
    }

    private func convert(_ point: CGPoint, to view: UIView?) -> CGPoint {
        guard let view, let window else { return point }
        return view.convert(point, from: window)
    }

    // MARK: Iris: delivery

    public override init() {
        UITouch.made += 1
        number = UITouch.made
        super.init()
    }

    /// Orders touches as they came, so that delivery doesn't depend on hashing.
    let number: Int
    private static var made = 0

    var recognizers: [UIGestureRecognizer] = []
    /// False when another view takes touches exclusively: nothing gets this one.
    var isDelivered = true
    /// False when the view has a touch already and takes one at a time.
    var reachesView = true
    /// Phases the view has yet to get: recognizers can hold them back until they decide.
    var heldPhases: [UITouch.Phase] = []
    var viewBegan = false
    var viewFinished = false
    /// A recognizer that recognized took the touch: the view gets `touchesCancelled`.
    var isClaimed = false

    var hasLifted: Bool {
        phase == .ended || phase == .cancelled
    }
}

extension UITouch {
    public enum Phase: Int, Sendable {
        case began = 0, moved, stationary, ended, cancelled
        case regionEntered, regionMoved, regionExited
    }

    public enum TouchType: Int, Sendable {
        case direct = 0, indirect, pencil, indirectPointer
    }
}

/// An event from the screen or a keyboard. For touches UIKit reuses one event, and its
/// `allTouches` are every finger on the screen.
@preconcurrency @MainActor
open class UIEvent: NSObject {
    open var type: UIEvent.EventType {
        .touches
    }

    open internal(set) var timestamp: TimeInterval = 0

    var touches: Set<UITouch> = []

    open var allTouches: Set<UITouch>? {
        touches
    }

    open func touches(for window: UIWindow) -> Set<UITouch>? {
        touches.filter { $0.window === window }
    }

    open func touches(for view: UIView) -> Set<UITouch>? {
        touches.filter { $0.view === view }
    }

    open func touches(for gesture: UIGestureRecognizer) -> Set<UITouch>? {
        touches.filter { $0.recognizers.contains(gesture) }
    }

    /// The touches between the last event and this one; Iris has one per event.
    open func coalescedTouches(for touch: UITouch) -> [UITouch]? {
        touches.contains(touch) ? [touch] : nil
    }

    open func predictedTouches(for touch: UITouch) -> [UITouch]? {
        touches.contains(touch) ? [] : nil
    }
}

extension UIEvent {
    public enum EventType: Int, Sendable {
        case touches = 0, motion, remoteControl, presses
        case scroll = 10, hover, transform = 14
    }
}
