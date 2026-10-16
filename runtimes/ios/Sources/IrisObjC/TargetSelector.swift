import Foundation

// Foundation's API that takes a target and a selector, which Foundation on Linux leaves out.
// What runs is the method `_IrisMethods` has for the selector. Timers here start with a fire
// date: Foundation on Linux fires `Timer(timeInterval:repeats:block:)` at once.

/// A target and a selector to send it, kept by a timer or a notification observer, which
/// Foundation runs off the main actor.
private final class Message: @unchecked Sendable {
    let selector: Selector
    let argument: Any?
    private let strongTarget: AnyObject?
    private weak var weakTarget: AnyObject?

    init(_ selector: Selector, to target: Any, with argument: Any? = nil, retained: Bool) {
        self.selector = selector
        self.argument = argument
        strongTarget = retained ? target as AnyObject : nil
        weakTarget = target as AnyObject
    }

    var target: AnyObject? {
        strongTarget ?? weakTarget
    }

    /// Sends the selector with these arguments, or its own argument; false once the target is gone.
    @discardableResult
    func send(_ arguments: [Any?]? = nil) -> Bool {
        guard let target else { return false }
        _IrisMethods.send(selector, to: target, with: arguments ?? [argument])
        return true
    }
}

// MARK: Timers

/// A timer with the `userInfo` it was made with, which Foundation on Linux's timers can't hold.
private final class SelectorTimer: Timer {
    var info: Any?

    override var userInfo: Any? {
        info
    }
}

extension Timer {
    /// Sends `aSelector` to `aTarget`, which the timer keeps, with the timer as its argument.
    // ponytail: `userInfo` stays nil on timers made this way (Foundation on Linux has no setter);
    // scheduledTimer keeps it.
    public convenience init(timeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) {
        let message = Message(aSelector, to: aTarget, retained: true)
        self.init(fire: Date(timeIntervalSinceNow: ti), interval: ti, repeats: yesOrNo) { message.send([$0]) }
    }

    public convenience init(fireAt date: Date, interval ti: TimeInterval, target t: Any, selector s: Selector, userInfo ui: Any?, repeats rep: Bool) {
        let message = Message(s, to: t, retained: true)
        self.init(fire: date, interval: ti, repeats: rep) { message.send([$0]) }
    }

    @discardableResult
    public class func scheduledTimer(timeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        let message = Message(aSelector, to: aTarget, retained: true)
        let timer = SelectorTimer(fire: Date(timeIntervalSinceNow: ti), interval: ti, repeats: yesOrNo) { message.send([$0]) }
        timer.info = userInfo
        RunLoop.current.add(timer, forMode: .default)
        return timer
    }
}

// MARK: Delayed performs

/// Performs waiting for their delay, for `cancelPreviousPerformRequests`.
nonisolated(unsafe) private var delayedPerforms: [(message: Message, timer: Timer)] = []
private let delayedPerformsLock = NSLock()

extension NSObject {
    /// Sends `aSelector` to this object, which is kept until then, on the current run loop
    /// after `delay` seconds.
    public func perform(_ aSelector: Selector, with anArgument: Any?, afterDelay delay: TimeInterval) {
        perform(aSelector, with: anArgument, afterDelay: delay, inModes: [.default])
    }

    public func perform(_ aSelector: Selector, with anArgument: Any?, afterDelay delay: TimeInterval, inModes modes: [RunLoop.Mode]) {
        let message = Message(aSelector, to: self, with: anArgument, retained: true)
        let timer = Timer(fire: Date(timeIntervalSinceNow: delay), interval: 0, repeats: false) { timer in
            delayedPerformsLock.withLock { delayedPerforms.removeAll { $0.timer === timer } }
            message.send()
        }
        delayedPerformsLock.withLock { delayedPerforms.append((message, timer)) }
        for mode in modes {
            RunLoop.current.add(timer, forMode: mode)
        }
    }

    public class func cancelPreviousPerformRequests(withTarget aTarget: Any) {
        cancelPerforms { $0.target === aTarget as AnyObject }
    }

    /// Cancels the performs of `aSelector` with an argument equal to `anArgument`.
    public class func cancelPreviousPerformRequests(withTarget aTarget: Any, selector aSelector: Selector, object anArgument: Any?) {
        cancelPerforms { message in
            guard message.target === aTarget as AnyObject, message.selector == aSelector else { return false }
            switch (message.argument, anArgument) {
            case (nil, nil): return true
            case let (argument?, other?):
                if let argument = argument as? AnyHashable, let other = other as? AnyHashable {
                    return argument == other
                }
                return argument as AnyObject === other as AnyObject
            default: return false
            }
        }
    }

    private class func cancelPerforms(where matches: (Message) -> Bool) {
        let cancelled = delayedPerformsLock.withLock {
            let cancelled = delayedPerforms.filter { matches($0.message) }
            delayedPerforms.removeAll { matches($0.message) }
            return cancelled
        }
        for perform in cancelled {
            perform.timer.invalidate()
        }
    }

    public func performSelector(onMainThread aSelector: Selector, with arg: Any?, waitUntilDone wait: Bool) {
        let message = Message(aSelector, to: self, with: arg, retained: true)
        if Thread.isMainThread, wait {
            message.send()
        } else if wait {
            DispatchQueue.main.sync { _ = message.send() }
        } else {
            DispatchQueue.main.async { message.send() }
        }
    }
}

// MARK: Notifications

/// The observers added with a selector, by observer, for `_irisRemoveObserver`.
nonisolated(unsafe) private var selectorObservers: [(observer: Message, name: NSNotification.Name?, object: AnyObject?, token: NSObjectProtocol)] = []
private let selectorObserversLock = NSLock()

extension NotificationCenter {
    /// Sends `aSelector` to `observer` with each notification. The center doesn't keep the
    /// observer, and stops once it is gone, as on iOS 9 and later.
    public func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name?, object anObject: Any?) {
        let message = Message(aSelector, to: observer, retained: false)
        nonisolated(unsafe) var token: NSObjectProtocol?
        token = addObserver(forName: aName, object: anObject, queue: nil) { [unowned self] notification in
            if !message.send([notification]), let token {
                self._irisRemove { $0.token === token }
            }
        }
        selectorObserversLock.withLock {
            selectorObservers.append((message, aName, anObject.map { $0 as AnyObject }, token!))
        }
    }

    /// Iris: `removeObserver(_:)` for observers added with a selector too. Foundation's can't
    /// see them, and an extension can't replace it, so irisrun-ios-build (P1-35) calls this one.
    public func _irisRemoveObserver(_ observer: Any) {
        _irisRemove { $0.observer.target === observer as AnyObject }
        removeObserver(observer)
    }

    /// Iris: `removeObserver(_:name:object:)` for observers added with a selector too.
    public func _irisRemoveObserver(_ observer: Any, name aName: NSNotification.Name?, object anObject: Any?) {
        _irisRemove {
            $0.observer.target === observer as AnyObject && (aName == nil || $0.name == aName)
                && (anObject == nil || $0.object === anObject as AnyObject)
        }
        removeObserver(observer, name: aName, object: anObject)
    }

    private func _irisRemove(where matches: ((observer: Message, name: NSNotification.Name?, object: AnyObject?, token: NSObjectProtocol)) -> Bool) {
        let removed = selectorObserversLock.withLock {
            let removed = selectorObservers.filter(matches)
            selectorObservers.removeAll(where: matches)
            return removed
        }
        for observer in removed {
            removeObserver(observer.token)
        }
    }
}
