import Foundation
import IrisHost
import IrisRender
@testable import OpenUIKit
import Testing

// Appearance callbacks in UIKit's order, presentations and dismissals, and the rest of
// UIView's animations. Tests run as a script does: a transition happens at once, and viewDid…
// and completions on the main queue's next turn, which a short sleep lets come.

/// What the view controllers of a test heard, in order.
@MainActor
final class Journal {
    var entries: [String] = []
}

/// A view controller that writes its appearance callbacks to a journal, with what UIKit says
/// about them: animated, being presented or dismissed, moving to or from its parent.
@MainActor
class Logged: UIViewController, UIAdaptivePresentationControllerDelegate {
    let name: String
    let journal: Journal

    init(_ name: String, _ journal: Journal) {
        self.name = name
        self.journal = journal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func log(_ event: String, _ animated: Bool) {
        var entry = "\(name) \(event)"
        for (flag, word) in [(animated, "animated"), (isBeingPresented, "presented"), (isBeingDismissed, "dismissed"), (isMovingToParent || isMovingFromParent, "moving")] where flag {
            entry += " " + word
        }
        journal.entries.append(entry)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        journal.entries.append("\(name) load")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log("willAppear", animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log("didAppear", animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        log("willDisappear", animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        log("didDisappear", animated)
    }

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        journal.entries.append("\(name) hears: will dismiss")
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        journal.entries.append("\(name) hears: did dismiss")
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        journal.entries.append("\(name) hears: attempt")
    }
}

/// Tests that keep a window on screen across turns of the main queue, one at a time, as a window
/// another one put in front would take their touches.
@Suite(.serialized) @MainActor struct OnScreen {}

/// Lets the main queue run what a transition left for its next turn.
@MainActor
func nextTurn() async throws {
    try await Task.sleep(for: .milliseconds(10))
}

/// A visible window with a root view controller that has appeared.
@MainActor
func show(_ root: UIViewController) async throws -> UIWindow {
    makeScene()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = root
    window.isHidden = false
    try await nextTurn()
    return window
}

@MainActor @Test func animatedViewsTakeNoTouchesAndInterruptedAnimationsGoOnFromWhatShows() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let box = UIView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    screen.root.addSubview(box)
    irisAnimates = true
    defer { irisAnimates = false }
    UIView.animate(withDuration: 5) { box.alpha = 0.5 }
    #expect(screen.input.hitTest(CGPoint(x: 150, y: 150)) === screen.root, "as in UIKit, unless asked")
    let other = UIView(frame: CGRect(x: 100, y: 300, width: 100, height: 100))
    screen.root.addSubview(other)
    UIView.animate(withDuration: 5, delay: 0, options: .allowUserInteraction) { other.alpha = 0.5 }
    #expect(screen.input.hitTest(CGPoint(x: 150, y: 350)) === other)

    // An animation that interrupts another starts from where that one got, not from its end.
    let scene = IrisRender.Scene(width: 390, height: 844, scale: 1)
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    scene.time = 10
    _ = layer.draw(in: scene)
    UIView.animate(withDuration: 1, delay: 0, options: .curveLinear) { layer.position.x = 125 }
    _ = layer.draw(in: scene)
    scene.time = 10.5
    let rendered = try! #require(layer.renderLayer)
    guard case let .frame(midway) = rendered.shown(.frame(rendered.frame)) else { return }
    #expect(midway.x == 50)
    UIView.animate(withDuration: 1) { layer.position.x = 25 }
    _ = layer.draw(in: scene)
    guard case let .frame(start) = rendered.shown(.frame(rendered.frame)) else { return }
    #expect(start.x == 50 && rendered.frame.x == 0)
}

@MainActor @Test func transitionsAndKeyframesTimeTheirChanges() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    let label = UIView()
    container.addSubview(label)
    // A transition fades in what the view shows next; the block's changes animate only with
    // allowAnimatedContent.
    UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: { label.backgroundColor = .red })
    #expect(label.layer.irisAnimations.count == 1 && label.layer.irisAnimation == nil)
    UIView.transition(with: label, duration: 0.3, options: [.transitionFlipFromLeft, .allowAnimatedContent], animations: { label.alpha = 0.5 })
    #expect(label.layer.irisAnimations.count == 2 && label.layer.irisAnimation?.duration == 0.3)
    // One view in place of another, or one shown in place of a hidden one.
    let next = UIView()
    UIView.transition(from: label, to: next, duration: 0.3, options: .transitionCrossDissolve)
    #expect(label.superview == nil && next.superview === container && next.layer.irisAnimations.count == 1)
    UIView.transition(from: next, to: label, duration: 0, options: .showHideTransitionViews)
    #expect(next.isHidden && next.superview === container && label.superview == nil)
    // A keyframe animates over its part of the duration, linearly.
    UIView.animateKeyframes(withDuration: 2, delay: 1, options: []) {
        UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.5) { next.alpha = 0.2 }
    }
    let keyframe = try! #require(next.layer.irisAnimation)
    #expect(keyframe.delay == 1.5 && keyframe.duration == 1 && keyframe.curve.x1 == 0 && keyframe.curve.x2 == 1)
}

extension OnScreen {
    @Test func rootViewControllersAppearWithTheirWindow() async throws {
        makeScene()
        let journal = Journal()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let first = Logged("A", journal)
        window.rootViewController = first
        #expect(journal.entries.isEmpty, "not before the window shows")
        // As makeKeyAndVisible does: viewWillAppear before the view is in the window, viewDidAppear
        // once the turn is over and the view laid out.
        window.isHidden = false
        #expect(journal.entries == ["A load", "A willAppear"] && first.view.window === window)
        try await nextTurn()
        #expect(journal.entries == ["A load", "A willAppear", "A didAppear"])
        // A new root takes the old one's place.
        journal.entries = []
        let second = Logged("B", journal)
        window.rootViewController = second
        #expect(journal.entries == ["B load", "A willDisappear", "B willAppear"])
        #expect(first.view.window == nil && second.view.window === window)
        try await nextTurn()
        #expect(journal.entries.suffix(2) == ["A didDisappear", "B didAppear"])
        journal.entries = []
        window.isHidden = true
        try await nextTurn()
        #expect(journal.entries == ["B willDisappear", "B didDisappear"])
    }

    @Test func fullScreenPresentationsCoverThePresenterInUIKitsOrder() async throws {
        let journal = Journal()
        let root = Logged("A", journal)
        let window = try await show(root)
        defer { window.isHidden = true }
        journal.entries = []
        let modal = Logged("B", journal)
        modal.modalPresentationStyle = .fullScreen
        root.present(modal, animated: true) { journal.entries.append("presented") }
        #expect(journal.entries == ["B load", "A willDisappear animated", "B willAppear animated presented"])
        #expect(root.presentedViewController === modal && modal.presentingViewController === root && modal.view.window === window)
        try await nextTurn()
        // The presented view controller ends first, then the one it covers, whose view leaves.
        #expect(journal.entries.suffix(3) == ["B didAppear animated presented", "A didDisappear animated", "presented"])
        #expect(!modal.isBeingPresented && root.view.window == nil)
        #expect(modal.view.frame == window.bounds && modal.view.safeAreaInsets == UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0))
        journal.entries = []
        modal.dismiss(animated: true) { journal.entries.append("dismissed") }
        #expect(journal.entries == ["B willDisappear animated dismissed", "A willAppear animated"])
        #expect(root.view.window === window && modal.view.window == nil, "a script shows where the transition ends")
        try await nextTurn()
        #expect(journal.entries.suffix(3) == ["B didDisappear animated dismissed", "A didAppear animated", "dismissed"])
        #expect(root.presentedViewController == nil && modal.presentingViewController == nil && !modal.isBeingDismissed)
    }

    @Test func pageSheetsComeOverTheirPresenterAndADragDismissesThem() async throws {
        makeScene()
        let screen = Screen()
        defer { screen.close() }
        let journal = Journal()
        let root = Logged("A", journal)
        screen.window.rootViewController = root
        try await nextTurn()
        journal.entries = []
        let sheet = Logged("B", journal)
        sheet.presentationController?.delegate = sheet
        root.present(sheet, animated: true)
        #expect(journal.entries == ["B load", "B willAppear animated presented"], "the presenter stays on screen")
        // The card is 10 points below the safe area and reaches the bottom; its safe area is clear
        // of the home indicator only. The view under it recedes, rounded.
        #expect(sheet.view.convert(sheet.view.bounds, to: nil) == CGRect(x: 0, y: 57, width: 390, height: 787))
        #expect(sheet.view.safeAreaInsets == UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0))
        let receded = root.view.layer.irisPresentationTransform
        #expect(abs(receded.a - 358.0 / 390) < 0.001 && abs(422 + receded.ty - 844 * receded.a / 2 - 47) < 0.01)
        #expect(root.view.layer.irisPresentationCornerRadius == 10 && root.view.window != nil)
        let card = try #require(sheet.sheetPresentationController?.presentedView)
        #expect(card.layer.cornerRadius == 10 && card.frame.maxY == 854, "its rounded bottom is off screen")
        try await nextTurn()
        #expect(journal.entries.last == "B didAppear animated presented")
        // A short drag springs back; a long one dismisses it, and the delegate hears of it.
        journal.entries = []
        screen.drag(from: CGPoint(x: 195, y: 300), to: CGPoint(x: 195, y: 360))
        #expect(root.presentedViewController === sheet && journal.entries.isEmpty && card.layer.irisPresentationTransform == .identity)
        screen.drag(from: CGPoint(x: 195, y: 300), to: CGPoint(x: 195, y: 800))
        #expect(journal.entries == ["B hears: will dismiss", "B willDisappear animated dismissed"])
        try await nextTurn()
        #expect(journal.entries.suffix(2) == ["B didDisappear animated dismissed", "B hears: did dismiss"])
        #expect(root.presentedViewController == nil && root.view.layer.irisPresentationTransform == .identity && root.view.layer.irisPresentationCornerRadius == nil)
        // One that may not go stays, and the delegate hears of the attempt.
        sheet.isModalInPresentation = true
        root.present(sheet, animated: false)
        try await nextTurn()
        journal.entries = []
        screen.drag(from: CGPoint(x: 195, y: 300), to: CGPoint(x: 195, y: 800))
        #expect(journal.entries == ["B hears: attempt"] && root.presentedViewController === sheet)
        // Detents: at the medium one the card is half as high, above the home indicator.
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.containerView?.layoutIfNeeded()
        #expect(sheet.view.convert(sheet.view.bounds, to: nil).minY == 844 - 753.0 / 2 - 34)
        sheet.dismiss(animated: false)
        try await nextTurn()
    }

    @Test func dismissingFromTheMiddleTakesTheOnesAbove() async throws {
        let journal = Journal()
        let root = Logged("A", journal)
        let child = Logged("C", journal)
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        let window = try await show(root)
        defer { window.isHidden = true }
        // A child presents through the top of its hierarchy, and sees what its parent presents.
        let sheet = Logged("B", journal)
        child.present(sheet, animated: false)
        #expect(sheet.presentingViewController === root && child.presentedViewController === sheet && root.presentedViewController === sheet)
        child.present(Logged("X", journal), animated: false)
        #expect(root.presentedViewController === sheet, "one that presents already presents nothing")
        try await nextTurn()
        let cover = Logged("D", journal)
        cover.modalPresentationStyle = .fullScreen
        sheet.present(cover, animated: false)
        try await nextTurn()
        #expect(journal.entries.contains("B didDisappear") && !journal.entries.contains("A willDisappear"), "a sheet presents the cover")
        // The child dismisses what its parent presented, and what that one presented: only the top
        // one goes with a transition.
        journal.entries = []
        child.dismiss(animated: true) { journal.entries.append("dismissed") }
        #expect(journal.entries == ["D willDisappear animated dismissed"])
        #expect(sheet.viewIfLoaded?.window == nil && cover.viewIfLoaded?.window == nil)
        try await nextTurn()
        #expect(journal.entries == ["D willDisappear animated dismissed", "D didDisappear animated dismissed", "dismissed"])
        #expect(root.presentedViewController == nil && sheet.presentedViewController == nil && cover.presentingViewController == nil)
    }

    @Test func overTheCurrentContextCoversTheViewControllerThatDefinesIt() async throws {
        let journal = Journal()
        let root = Logged("A", journal)
        let context = Logged("C", journal)
        context.definesPresentationContext = true
        root.addChild(context)
        root.view.addSubview(context.view)
        context.view.frame = CGRect(x: 0, y: 100, width: 390, height: 300)
        context.didMove(toParent: root)
        let inner = Logged("I", journal)
        context.addChild(inner)
        context.view.addSubview(inner.view)
        inner.didMove(toParent: context)
        let window = try await show(root)
        defer { window.isHidden = true }
        // A child of the context presents; the context does, over its own frame, and stays.
        let overlay = Logged("O", journal)
        overlay.modalPresentationStyle = .overCurrentContext
        overlay.modalTransitionStyle = .crossDissolve
        journal.entries = []
        inner.present(overlay, animated: true)
        #expect(overlay.presentingViewController === context && inner.presentedViewController === overlay && root.presentedViewController == nil)
        #expect(overlay.view.convert(overlay.view.bounds, to: nil) == CGRect(x: 0, y: 100, width: 390, height: 300))
        #expect(context.view.window === window && journal.entries == ["O load", "O willAppear animated presented"])
        try await nextTurn()
        overlay.dismiss(animated: true)
        try await nextTurn()
        #expect(context.presentedViewController == nil && overlay.viewIfLoaded?.window == nil)
        #expect(journal.entries.suffix(2) == ["O willDisappear animated dismissed", "O didDisappear animated dismissed"])
    }

    @Test func dismissedViewControllersGoAway() async throws {
        let journal = Journal()
        let root = Logged("A", journal)
        let window = try await show(root)
        defer { window.isHidden = true }
        weak var gone: UIViewController?
        do {
            let sheet = Logged("B", journal)
            sheet.presentationController?.delegate = sheet
            gone = sheet
            root.present(sheet, animated: true)
        }
        try await nextTurn()
        root.dismiss(animated: true)
        try await nextTurn()
        #expect(gone == nil, "nothing keeps it, nor its presentation controller, once dismissed")
    }

    @Test func childrenAppearWithTheirParentOrWithTheirViews() async throws {
        let journal = Journal()
        let parent = Logged("P", journal)
        let early = Logged("E", journal)
        parent.addChild(early)
        parent.view.addSubview(early.view)
        early.didMove(toParent: parent)
        let window = try await show(parent)
        defer { window.isHidden = true }
        // Forwarded after the parent's own.
        #expect(journal.entries == ["P load", "E load", "P willAppear", "E willAppear", "P didAppear", "E didAppear"])
        // A child added to a parent on screen appears with its view, moving to the parent until
        // didMove(toParent:); it disappears with its view, moving from it.
        journal.entries = []
        let late = Logged("L", journal)
        parent.addChild(late)
        parent.view.addSubview(late.view)
        late.didMove(toParent: parent)
        #expect(journal.entries == ["L load", "L willAppear moving", "L didAppear moving"] && !late.isMovingToParent)
        late.willMove(toParent: nil)
        late.view.removeFromSuperview()
        late.removeFromParent()
        #expect(journal.entries.suffix(2) == ["L willDisappear moving", "L didDisappear moving"] && !late.isMovingFromParent)
        // A container that forwards nothing itself tells its children.
        final class Manual: Logged {
            override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
        }
        let manual = Manual("M", journal)
        let inner = Logged("I", journal)
        manual.addChild(inner)
        manual.view.addSubview(inner.view)
        journal.entries = []
        parent.addChild(manual)
        parent.view.addSubview(manual.view)
        #expect(journal.entries == ["M willAppear moving", "M didAppear moving"])
        inner.beginAppearanceTransition(true, animated: true)
        inner.endAppearanceTransition()
        inner.endAppearanceTransition()
        #expect(journal.entries.suffix(2) == ["I willAppear animated moving", "I didAppear animated moving"], "an unbalanced end does nothing")
    }

    @Test func aViewHiddenInAStackViewShowsUntilTheAnimationEnds() async throws {
        makeScene()
        let screen = Screen()
        defer { screen.close() }
        let first = UIView(), second = UIView()
        let stack = UIStackView(arrangedSubviews: [first, second])
        stack.frame = CGRect(x: 0, y: 100, width: 390, height: 50)
        screen.root.addSubview(stack)
        LayerCommit.commit()
        irisAnimates = true
        UIView.animate(withDuration: 0.2) { second.isHidden = true }
        irisAnimates = false
        LayerCommit.commit()
        #expect(second.isHidden && second.layer.renderLayer?.isHidden == false, "it shows while its room closes")
        try await Task.sleep(for: .milliseconds(300))
        LayerCommit.commit()
        #expect(second.layer.renderLayer?.isHidden == true)
    }
}
