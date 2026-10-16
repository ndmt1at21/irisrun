import Foundation
import IrisHost
@testable import OpenUIKit
import Testing

// Touches, the responder chain, controls, gesture recognizers and selectors, driven through
// the same entry point as a phone's input (`TouchInput`).

/// Every call the views, controls and targets of a test saw, in order.
nonisolated(unsafe) private var log: [String] = []

/// A view that logs the touches it gets, then lets UIResponder forward them.
final class LoggingView: UIView {
    var name = ""

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        log.append("\(name) began")
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        log.append("\(name) moved")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        log.append("\(name) ended")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        log.append("\(name) cancelled")
    }
}

/// An app class with `@objc` methods, as irisrun-ios-build (P1-35) registers them.
@MainActor
private class Target: NSObject {
    func tapped(_ sender: Any) {
        log.append("tapped \(type(of: sender))")
    }

    func handle(_ recognizer: UIGestureRecognizer) {
        log.append("\(type(of: recognizer)) \(recognizer.state)")
    }

    func reset() {
        log.append("reset")
    }

    func touched(_ sender: UIControl, event: UIEvent?) {
        log.append("touched with \(event == nil ? "no event" : "event")")
    }

    func greeting() -> NSString {
        "hello"
    }
}

private final class SubTarget: Target {
    override func reset() {
        log.append("sub reset")
    }
}

/// What irisrun-ios-build appends to a file with `@objc` methods, called once before the
/// module makes its first selector.
private func registerMethods() {
    _IrisMethods.register(Target.self, [
        "tapped:": .init(Target.tapped(_:)),
        "handle:": .init(Target.handle(_:)),
        "reset": .init(Target.reset),
        "touched:event:": .init(Target.touched(_:event:)),
        "greeting": .init(Target.greeting),
    ])
    _IrisMethods.register(SubTarget.self, ["reset": .init(SubTarget.reset)])
}

private let methodsRegistered: Void = registerMethods()

/// A window on screen with a 390 × 844 root view, for a test's touches.
@MainActor
final class Screen {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let root = LoggingView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let input = TouchInput()
    var time: TimeInterval = 1000

    init() {
        _ = methodsRegistered
        log = []
        root.name = "root"
        window.addSubview(root)
        window.isHidden = false
    }

    func close() {
        window.isHidden = true
        UIResponder.first = nil
    }

    func touch(_ phase: DeviceTouch.Phase, _ x: CGFloat, _ y: CGFloat, finger: UInt32 = 0, after seconds: TimeInterval = 1.0 / 60) {
        time += seconds
        input.touch([DeviceTouch(id: finger, phase: phase, location: CGPoint(x: x, y: y))], at: time)
    }

    func tap(_ x: CGFloat, _ y: CGFloat) {
        touch(.began, x, y, after: 1)
        touch(.ended, x, y)
    }

    /// Down at the first point, ten moves to the second, then up.
    func drag(from a: CGPoint, to b: CGPoint) {
        touch(.began, a.x, a.y, after: 1)
        for step in 1 ... 10 {
            let t = CGFloat(step) / 10
            touch(.moved, a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
        }
        touch(.ended, b.x, b.y)
    }
}

// MARK: Touches and responders

@MainActor @Test func touchesStayWithTheViewTheyBeganIn() {
    let screen = Screen()
    defer { screen.close() }
    let card = LoggingView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    card.name = "card"
    screen.root.addSubview(card)
    var touch: UITouch?
    final class Spy: UIView {
        var onMove: ((UITouch) -> Void)?
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            onMove?(touches.first!)
        }
    }
    let spy = Spy(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
    spy.onMove = { touch = $0 }
    card.addSubview(spy)

    screen.touch(.began, 115, 115)
    screen.touch(.moved, 300, 400)
    #expect(touch?.view === spy && touch?.window === screen.window && touch?.phase == .moved)
    #expect(touch?.location(in: nil) == CGPoint(x: 300, y: 400))
    #expect(touch?.location(in: card) == CGPoint(x: 200, y: 300))
    #expect(touch?.previousLocation(in: spy) == CGPoint(x: 5, y: 5))
    #expect(touch?.gestureRecognizers == [])
    screen.touch(.ended, 300, 400)
    // The spy took moves itself; the rest went up the chain: spy, card, root.
    #expect(log == ["card began", "root began", "card ended"])

    // Views that don't take touches are passed over.
    card.isUserInteractionEnabled = false
    log = []
    screen.tap(150, 150)
    #expect(log == ["root began", "root ended"])
}

@MainActor @Test func repeatedTapsCountUp() {
    let screen = Screen()
    defer { screen.close() }
    var counts: [Int] = []
    final class Counter: UIView {
        var onBegan: ((Int) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onBegan?(touches.first!.tapCount)
        }
    }
    let counter = Counter(frame: screen.root.bounds)
    counter.onBegan = { counts.append($0) }
    screen.root.addSubview(counter)
    screen.touch(.began, 100, 100)
    screen.touch(.ended, 100, 100)
    screen.touch(.began, 104, 98, after: 0.2)
    screen.touch(.ended, 104, 98)
    screen.touch(.began, 100, 100, after: 0.2)
    screen.touch(.ended, 100, 100)
    // Too late, then too far.
    screen.touch(.began, 100, 100, after: 1)
    screen.touch(.ended, 100, 100)
    screen.touch(.began, 300, 100, after: 0.1)
    screen.touch(.ended, 300, 100)
    #expect(counts == [1, 2, 3, 1, 1])
}

@MainActor @Test func viewsTakeOneTouchUnlessMultipleTouchIsOn() {
    let screen = Screen()
    defer { screen.close() }
    let pad = LoggingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    pad.name = "pad"
    screen.root.addSubview(pad)
    screen.touch(.began, 50, 50, finger: 1)
    screen.touch(.began, 100, 100, finger: 2)
    screen.touch(.ended, 50, 50, finger: 1)
    screen.touch(.ended, 100, 100, finger: 2)
    #expect(log == ["pad began", "root began", "pad ended"])

    pad.isMultipleTouchEnabled = true
    log = []
    screen.touch(.began, 50, 50, finger: 1)
    screen.touch(.began, 100, 100, finger: 2)
    screen.touch(.ended, 50, 50, finger: 1)
    screen.touch(.ended, 100, 100, finger: 2)
    #expect(log.filter { $0.hasPrefix("pad") } == ["pad began", "pad began", "pad ended", "pad ended"])

    // While a finger is on an exclusive view, other views get nothing, and the other way round.
    let other = LoggingView(frame: CGRect(x: 200, y: 400, width: 100, height: 100))
    other.name = "other"
    screen.root.addSubview(other)
    pad.isExclusiveTouch = true
    log = []
    screen.touch(.began, 50, 50, finger: 1)
    screen.touch(.began, 250, 450, finger: 2)
    screen.touch(.ended, 50, 50, finger: 1)
    screen.touch(.ended, 250, 450, finger: 2)
    #expect(!log.contains("other began"))
}

@MainActor @Test func actionsSentToNilGoUpTheResponderChain() {
    let screen = Screen()
    defer { screen.close() }
    final class Controller: UIViewController {}
    let controller = Controller()
    _IrisMethods.register(Controller.self, ["save": .init(Controller.save)])
    screen.root.addSubview(controller.view)
    let button = UIControl(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    controller.view.addSubview(button)
    #expect(button.target(forAction: "save", withSender: nil) as? Controller === controller)
    #expect(UIApplication.shared.sendAction("save", to: nil, from: button, for: nil))
    #expect(log == ["saved"])
    #expect(!UIApplication.shared.sendAction("missing", to: nil, from: button, for: nil))

    // The first responder is asked first.
    final class Field: UIView {
        override var canBecomeFirstResponder: Bool { true }
    }
    let field = Field()
    #expect(!field.becomeFirstResponder(), "not in a window")
    screen.root.addSubview(field)
    #expect(field.becomeFirstResponder() && field.isFirstResponder)
    #expect(UIApplication.shared.sendAction("resignFirstResponder", to: nil, from: nil, for: nil))
    #expect(!field.isFirstResponder)
}

extension UIViewController {
    fileprivate func save() {
        log.append("saved")
    }
}

// MARK: Selectors

@MainActor @Test func selectorsCallRegisteredMethodsUpTheClassChain() {
    _ = methodsRegistered
    log = []
    let target = Target()
    let sub = SubTarget()
    #expect(Selector("tapped:") == "tapped:" && Selector("tapped:").description == "tapped:")
    #expect(NSStringFromSelector(NSSelectorFromString("reset")) == "reset")
    #expect(target.responds(to: "tapped:") && sub.responds(to: "tapped:"))
    #expect(!target.responds(to: "tapped") && !target.responds(to: nil))
    target.perform("reset")
    sub.perform("reset")
    sub.perform("tapped:", with: 42)
    sub.perform("touched:event:", with: UIControl(), with: nil)
    #expect(log == ["reset", "sub reset", "tapped Int", "touched with no event"])
    #expect(target.perform("greeting")?.takeUnretainedValue() as? NSString == "hello")
    #expect(target.perform("reset") == nil)
}

@MainActor @Test func foundationSendsSelectorsForNotificationsAndTimers() {
    _ = methodsRegistered
    log = []
    let center = NotificationCenter()
    let name = Notification.Name("IrisTest")
    var target: Target? = Target()
    center.addObserver(target!, selector: "tapped:", name: name, object: nil)
    center.post(name: name, object: nil)
    #expect(log == ["tapped Notification"])
    center._irisRemoveObserver(target!)
    center.post(name: name, object: nil)
    #expect(log.count == 1)
    // Observers that went away get nothing.
    center.addObserver(target!, selector: "tapped:", name: name, object: nil)
    target = nil
    center.post(name: name, object: nil)
    #expect(log.count == 1)

    let timer = Timer.scheduledTimer(timeInterval: 60, target: Target(), selector: "tapped:", userInfo: "info", repeats: false)
    #expect(timer.userInfo as? String == "info")
    // Not at once, as Foundation on Linux fires Timer(timeInterval:repeats:block:).
    #expect(timer.fireDate.timeIntervalSinceNow > 59)
    #expect(Timer(timeInterval: 60, target: Target(), selector: "tapped:", userInfo: nil, repeats: false).fireDate.timeIntervalSinceNow > 59)
    let date = Date(timeIntervalSinceNow: 30)
    #expect(Timer(fireAt: date, interval: 0, target: Target(), selector: "tapped:", userInfo: nil, repeats: false).fireDate == date)
    timer.fire()
    #expect(log.last == "tapped SelectorTimer")
    timer.invalidate()
}

// MARK: Controls

/// A control whose events each log their name.
@MainActor
private func loggingControl(frame: CGRect) -> UIControl {
    let control = UIControl(frame: frame)
    let events: [(UIControl.Event, String)] = [
        (.touchDown, "down"), (.touchDownRepeat, "repeat"), (.touchDragInside, "drag inside"),
        (.touchDragOutside, "drag outside"), (.touchDragEnter, "enter"), (.touchDragExit, "exit"),
        (.touchUpInside, "up inside"), (.touchUpOutside, "up outside"), (.touchCancel, "cancel"),
    ]
    for (event, name) in events {
        control.addAction(UIAction { _ in log.append(name) }, for: event)
    }
    return control
}

@MainActor @Test func controlsTurnTouchesIntoEvents() {
    let screen = Screen()
    defer { screen.close() }
    let control = loggingControl(frame: CGRect(x: 100, y: 100, width: 100, height: 50))
    screen.root.addSubview(control)
    screen.touch(.began, 150, 125)
    #expect(control.isHighlighted && control.isTracking && control.state == .highlighted)
    screen.touch(.ended, 150, 125)
    #expect(log == ["down", "up inside"])
    #expect(!control.isHighlighted && !control.isTracking)

    // Within 70 points of the bounds a touch still counts as inside; beyond, it left.
    log = []
    screen.touch(.began, 150, 125, after: 1)
    screen.touch(.moved, 150, 210)
    #expect(control.isTouchInside && control.isHighlighted)
    screen.touch(.moved, 150, 260)
    #expect(!control.isHighlighted)
    screen.touch(.moved, 150, 140)
    screen.touch(.ended, 150, 300)
    #expect(log == ["down", "drag inside", "drag outside", "exit", "drag inside", "enter", "up outside"])

    // A second tap soon after counts as a repeat; a cancelled touch, as a cancel.
    log = []
    screen.tap(150, 125)
    screen.touch(.began, 150, 125, after: 0.1)
    screen.touch(.cancelled, 150, 125)
    #expect(log == ["down", "up inside", "down", "repeat", "cancel"])

    // A disabled control passes touches up the responder chain.
    log = []
    control.isEnabled = false
    #expect(control.state == .disabled)
    screen.tap(150, 125)
    #expect(log == ["root began", "root ended"])
}

@MainActor @Test func controlsKeepTheirTargetsAndActions() {
    _ = methodsRegistered
    log = []
    let control = UIControl()
    let target = Target()
    control.addTarget(target, action: "tapped:", for: .touchUpInside)
    control.addTarget(target, action: "tapped:", for: .touchUpInside)
    control.addTarget(nil, action: "reset", for: [.touchUpInside, .valueChanged])
    let action = UIAction(identifier: UIAction.Identifier("log")) { action in
        log.append("action from \(type(of: action.sender!))")
    }
    control.addAction(action, for: .touchUpInside)
    // The same identifier replaces the action.
    control.addAction(UIAction(identifier: UIAction.Identifier("log")) { _ in log.append("replacement") }, for: .touchUpInside)
    // On Linux two AnyHashable(NSNull()) compare equal but hash differently, so Set equality
    // with one is a coin toss; look for the nil target by type.
    #expect(control.allTargets.count == 2)
    #expect(control.allTargets.contains(AnyHashable(target)))
    #expect(control.allTargets.contains { $0.base is NSNull })
    #expect(control.allControlEvents == [.touchUpInside, .valueChanged])
    #expect(control.actions(forTarget: target, forControlEvent: .touchUpInside) == ["tapped:"])
    #expect(control.actions(forTarget: nil, forControlEvent: .valueChanged) == ["reset"])
    #expect(control.actions(forTarget: target, forControlEvent: .valueChanged) == nil)

    control.sendActions(for: .touchUpInside)
    // The nil target finds nothing in a control that isn't in a responder chain.
    #expect(log == ["tapped UIControl", "replacement"])

    log = []
    control.removeTarget(target, action: nil, for: .allEvents)
    control.removeAction(identifiedBy: UIAction.Identifier("log"), for: .touchUpInside)
    control.sendActions(for: .touchUpInside)
    #expect(log.isEmpty && control.allControlEvents == [.touchUpInside, .valueChanged])
    control.removeTarget(nil, action: "reset", for: .touchUpInside)
    #expect(control.allControlEvents == .valueChanged)

    // A primary action runs for primaryActionTriggered, with its sender set while it runs.
    let primary = UIAction(title: "Go") { log.append("primary \($0.title) \($0.sender is UIControl)") }
    UIControl(frame: .zero, primaryAction: primary).sendActions(for: .primaryActionTriggered)
    #expect(log == ["primary Go true"] && primary.sender == nil)
}

// MARK: Gesture recognizers

@MainActor @Test func aTapRecognizerSeesTouchesFirstAndCancelsThemInTheView() {
    let screen = Screen()
    defer { screen.close() }
    let card = LoggingView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    card.name = "card"
    screen.root.addSubview(card)
    let target = Target()
    let tap = UITapGestureRecognizer(target: target, action: "handle:")
    card.addGestureRecognizer(tap)
    #expect(card.gestureRecognizers == [tap] && tap.view === card)

    screen.tap(150, 150)
    #expect(log == ["card began", "root began", "UITapGestureRecognizer ended", "card cancelled"])
    #expect(tap.state == .possible, "reset after the event")

    // Too far is no tap: the view gets its touches.
    log = []
    screen.drag(from: CGPoint(x: 110, y: 110), to: CGPoint(x: 190, y: 190))
    #expect(log == ["card began", "root began"] + Array(repeating: "card moved", count: 10) + ["card ended"])

    // Without cancelling, the view gets touchesEnded after the action.
    log = []
    tap.cancelsTouchesInView = false
    tap.delaysTouchesBegan = true
    screen.tap(150, 150)
    #expect(log == ["UITapGestureRecognizer ended", "card began", "root began", "card ended"])
}

@MainActor @Test func aDoubleTapMakesASingleTapWait() {
    let screen = Screen()
    defer { screen.close() }
    let target = Target()
    let single = UITapGestureRecognizer(target: target, action: "handle:")
    let double = UITapGestureRecognizer(target: target, action: "reset")
    double.numberOfTapsRequired = 2
    single.require(toFail: double)
    screen.root.addGestureRecognizer(single)
    screen.root.addGestureRecognizer(double)

    screen.tap(100, 100)
    #expect(single.state == .possible && log == ["root began"], "the end waits for the double tap")
    screen.touch(.began, 100, 100, after: 0.2)
    screen.touch(.ended, 100, 100)
    // Both touches end cancelled: the first one's end waited for the double tap.
    #expect(log == ["root began", "root began", "reset", "root cancelled"])

    // One tap: the single tap goes once the double tap gave up.
    log = []
    screen.tap(100, 100)
    double.nextTapDidNotCome()
    GestureEnvironment.settle()
    #expect(log == ["root began", "UITapGestureRecognizer ended", "root cancelled"])
}

@MainActor @Test func aSuperviewsTapDoesNotTakeAControlsTap() {
    let screen = Screen()
    defer { screen.close() }
    let control = loggingControl(frame: CGRect(x: 100, y: 100, width: 100, height: 50))
    screen.root.addSubview(control)
    let target = Target()
    let tap = UITapGestureRecognizer(target: target, action: "handle:")
    screen.root.addGestureRecognizer(tap)
    screen.tap(150, 125)
    #expect(log == ["down", "up inside"])
    // Elsewhere the tap recognizes.
    log = []
    screen.tap(50, 500)
    #expect(log.contains("UITapGestureRecognizer ended"))
}

@MainActor @Test func aPanBeginsPastItsHysteresisAndTracksTheFinger() {
    let screen = Screen()
    defer { screen.close() }
    @MainActor
    final class Panner: NSObject {
        var translations: [CGPoint] = []
        var velocity = CGPoint.zero
        func handle(_ pan: UIPanGestureRecognizer) {
            log.append("pan \(pan.state)")
            translations.append(pan.translation(in: pan.view))
            velocity = pan.velocity(in: nil)
        }
    }
    _IrisMethods.register(Panner.self, ["handle:": .init(Panner.handle(_:))])
    let panner = Panner()
    let card = LoggingView(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
    card.name = "card"
    card.transform = CGAffineTransform(scaleX: 2, y: 2)
    screen.root.addSubview(card)
    let pan = UIPanGestureRecognizer(target: panner, action: "handle:")
    card.addGestureRecognizer(pan)

    screen.drag(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 260, y: 200))
    // 6 points a move: the second move passes 10 points and begins.
    #expect(log == ["card began", "root began", "card moved", "pan began", "card cancelled"]
        + Array(repeating: "pan changed", count: 8) + ["pan ended"])
    // In the card's coordinates, scaled twice, 60 points on screen are 30.
    #expect(panner.translations.first == CGPoint(x: 6, y: 0) && panner.translations.last == CGPoint(x: 30, y: 0))
    // 6 points every 60th of a second.
    #expect(abs(panner.velocity.x - 360) < 1e-6 && panner.velocity.y == 0)

    pan.setTranslation(.zero, in: nil)
    #expect(pan.translation(in: nil) == .zero)
}

@MainActor @Test func aLongPressBeginsWhenItsTimeIsUp() {
    let screen = Screen()
    defer { screen.close() }
    let target = Target()
    let press = UILongPressGestureRecognizer(target: target, action: "handle:")
    screen.root.addGestureRecognizer(press)
    screen.touch(.began, 100, 100)
    press.pressLastedLongEnough()
    GestureEnvironment.settle()
    screen.touch(.moved, 140, 100)
    screen.touch(.ended, 140, 100)
    #expect(log == ["root began", "UILongPressGestureRecognizer began", "root cancelled",
                    "UILongPressGestureRecognizer changed", "UILongPressGestureRecognizer ended"])

    // Moving too far, or lifting too soon, fails it.
    log = []
    screen.drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 140, y: 100))
    screen.tap(100, 100)
    #expect(!log.contains { $0.hasPrefix("UILongPress") })
}

@MainActor @Test func delegatesDecideWhoRecognizes() {
    let screen = Screen()
    defer { screen.close() }
    final class Delegate: NSObject, UIGestureRecognizerDelegate {
        var together = false
        var receives = true
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            together
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            receives
        }
    }
    let delegate = Delegate()
    let target = Target()
    let pan = UIPanGestureRecognizer(target: target, action: "handle:")
    let press = UILongPressGestureRecognizer(target: target, action: "handle:")
    press.minimumPressDuration = 0
    pan.delegate = delegate
    screen.root.addGestureRecognizer(pan)
    screen.root.addGestureRecognizer(press)

    // The long press begins first and keeps the touch.
    screen.touch(.began, 100, 100)
    press.pressLastedLongEnough()
    GestureEnvironment.settle()
    screen.touch(.moved, 150, 100)
    screen.touch(.ended, 150, 100)
    #expect(!log.contains { $0.hasPrefix("UIPan") })

    // Together, both recognize.
    log = []
    delegate.together = true
    screen.touch(.began, 100, 100)
    press.pressLastedLongEnough()
    GestureEnvironment.settle()
    screen.touch(.moved, 150, 100)
    screen.touch(.ended, 150, 100)
    #expect(log.contains("UIPanGestureRecognizer began"))

    // A recognizer the delegate keeps from a touch never sees it.
    log = []
    delegate.receives = false
    screen.drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 100))
    #expect(!log.contains { $0.hasPrefix("UIPan") })
}
