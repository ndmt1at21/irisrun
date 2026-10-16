import Foundation

/// How far fingers may stray, and how long taps may be apart, for UIKit's tap recognizers and
/// `UITouch.tapCount`. UIKit's values are private; these are close to how it behaves.
enum TapLimits {
    /// Points from where the first tap began.
    static let movement: CGFloat = 45
    /// Seconds from one tap lifting to the next touching.
    static let interval: TimeInterval = 0.35
}

/// Schedules `body` on the main run loop, in every mode, as UIKit's gesture timers run. (Foundation
/// on Linux fires `Timer(timeInterval:repeats:block:)` at once, so the timer gets a fire date.)
@MainActor
private func gestureTimer(after seconds: TimeInterval, _ body: @escaping @MainActor @Sendable () -> Void) -> Timer {
    let timer = Timer(fire: Date(timeIntervalSinceNow: seconds), interval: 0, repeats: false) { _ in
        MainActor.assumeIsolated(body)
    }
    RunLoop.main.add(timer, forMode: .common)
    return timer
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

/// Recognizes `numberOfTapsRequired` taps of `numberOfTouchesRequired` fingers, each tap close
/// to the first and soon after the last; it recognizes as the last tap lifts.
@preconcurrency @MainActor
open class UITapGestureRecognizer: UIGestureRecognizer {
    open var numberOfTapsRequired = 1
    open var numberOfTouchesRequired = 1

    private var taps = 0
    private var start: CGPoint?
    private var timer: Timer?

    override var awaitsTouches: Bool {
        taps > 0
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        timer?.invalidate()
        if start == nil {
            start = centroid
        }
        if self.touches.count > numberOfTouchesRequired {
            state = .failed
        }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let start, let centroid, distance(start, centroid) > TapLimits.movement {
            state = .failed
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        // A tap ends when its last finger lifts.
        guard self.touches.allSatisfy(\.hasLifted) else { return }
        guard self.touches.count == numberOfTouchesRequired else {
            state = .failed
            return
        }
        taps += 1
        if taps == numberOfTapsRequired {
            state = .ended
        } else {
            timer = gestureTimer(after: TapLimits.interval) { [weak self] in
                self?.nextTapDidNotCome()
            }
        }
    }

    func nextTapDidNotCome() {
        state = .failed
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override open func reset() {
        taps = 0
        start = nil
        timer?.invalidate()
        timer = nil
    }
}

/// Recognizes fingers dragging: it begins once they move `hysteresis` points, and changes as
/// they move on. The translation counts from where the fingers touched.
@preconcurrency @MainActor
open class UIPanGestureRecognizer: UIGestureRecognizer {
    open var minimumNumberOfTouches = 1
    open var maximumNumberOfTouches = Int.max

    /// Points the fingers move before the pan begins; UIKit's is private, about this.
    static let hysteresis: CGFloat = 10
    /// Seconds of movement that `velocity(in:)` looks back over.
    static let velocityWindow: TimeInterval = 0.1

    /// Where the translation counts from, in the window's coordinates.
    private var origin: CGPoint?
    /// Recent centroids as the fingers moved, and when the last event came, for the velocity.
    private var samples: [(time: TimeInterval, location: CGPoint)] = []
    private var lastEventTime: TimeInterval = 0

    /// How far the fingers moved since they touched, or since `setTranslation`.
    open func translation(in view: UIView?) -> CGPoint {
        guard let origin, let centroid else { return .zero }
        let from = point(origin, in: view)
        let to = point(centroid, in: view)
        return CGPoint(x: to.x - from.x, y: to.y - from.y)
    }

    open func setTranslation(_ translation: CGPoint, in view: UIView?) {
        guard let centroid else { return }
        let current = point(centroid, in: view)
        let origin = CGPoint(x: current.x - translation.x, y: current.y - translation.y)
        self.origin = view.map { $0.convert(origin, to: self.view?.window) } ?? origin
    }

    /// Points per second over the last tenth of a second of movement; zero once the fingers
    /// have rested longer than that.
    open func velocity(in view: UIView?) -> CGPoint {
        guard let last = samples.last, lastEventTime - last.time <= Self.velocityWindow,
              let first = samples.first(where: { last.time - $0.time <= Self.velocityWindow }),
              last.time > first.time
        else { return .zero }
        let from = point(first.location, in: view)
        let to = point(last.location, in: view)
        let seconds = CGFloat(last.time - first.time)
        return CGPoint(x: (to.x - from.x) / seconds, y: (to.y - from.y) / seconds)
    }

    private func record(_ event: UIEvent, moved: Bool) {
        lastEventTime = event.timestamp
        guard moved, let centroid else { return }
        samples.append((event.timestamp, centroid))
        samples.removeAll { event.timestamp - $0.time > Self.velocityWindow * 2 }
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches.sorted(by: { $0.number < $1.number }) where self.touches.count > maximumNumberOfTouches {
            ignore(touch, for: event)
        }
        // ponytail: the origin restarts at the new centroid when a finger joins before the pan
        // begins; after that, the translation jumps by half the new finger's offset.
        if state == .possible {
            origin = centroid
        }
        record(event, moved: true)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        record(event, moved: true)
        if state == .possible {
            if self.touches.count >= minimumNumberOfTouches, let origin, let centroid, distance(origin, centroid) > Self.hysteresis {
                state = .began
            }
        } else {
            state = .changed
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        record(event, moved: false)
        let down = self.touches.filter { !$0.hasLifted }.count
        if state == .possible {
            if down == 0 {
                state = .failed
            }
        } else if down < minimumNumberOfTouches {
            state = .ended
        }
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .possible ? .failed : .cancelled
    }

    override open func reset() {
        origin = nil
        samples = []
        lastEventTime = 0
    }
}

/// Recognizes fingers held still for `minimumPressDuration`, after `numberOfTapsRequired` taps:
/// it begins then, and changes as they move until they lift.
@preconcurrency @MainActor
open class UILongPressGestureRecognizer: UIGestureRecognizer {
    open var minimumPressDuration: TimeInterval = 0.5
    open var numberOfTouchesRequired = 1
    open var numberOfTapsRequired = 0
    /// Points the fingers may move before the press begins.
    open var allowableMovement: CGFloat = 10

    private var taps = 0
    private var start: CGPoint?
    private var timer: Timer?

    override var awaitsTouches: Bool {
        taps > 0
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        timer?.invalidate()
        guard self.touches.count <= numberOfTouchesRequired else {
            state = state == .possible ? .failed : .cancelled
            return
        }
        start = centroid
        if taps == numberOfTapsRequired, self.touches.count == numberOfTouchesRequired {
            timer = gestureTimer(after: minimumPressDuration) { [weak self] in
                self?.pressLastedLongEnough()
            }
        }
    }

    func pressLastedLongEnough() {
        if state == .possible {
            state = .began
        }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible {
            if let start, let centroid, distance(start, centroid) > allowableMovement {
                state = .failed
            }
        } else {
            state = .changed
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        let lifted = self.touches.allSatisfy(\.hasLifted)
        if state != .possible {
            if lifted {
                state = .ended
            }
        } else if taps < numberOfTapsRequired, lifted {
            // A tap before the press; the next one comes soon or the press fails.
            taps += 1
            timer = gestureTimer(after: TapLimits.interval) { [weak self] in
                guard let self, self.state == .possible else { return }
                self.state = .failed
            }
        } else {
            state = .failed
        }
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .possible ? .failed : .cancelled
    }

    override open func reset() {
        taps = 0
        start = nil
        timer?.invalidate()
        timer = nil
    }
}
