import Foundation
import IrisHost
import IrisRender
@testable import OpenUIKit
import Testing

// What OpenSwiftUI's hosting views rely on: a render layer of their own in the window's layer
// tree, the host's input while they have the keyboard, and view controller containment.

@Test func contentLayersStayAsTheirOwnerDrewThem() throws {
    let scene = IrisRender.Scene(width: 390, height: 844, scale: 1)
    let host = CALayer()
    host.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
    let content = IrisRender.Layer(in: scene)
    let drawn = IrisRender.Layer(in: scene)
    content.addSublayer(drawn)
    host._irisContentLayer = content
    let above = CALayer()
    host.addSublayer(above)
    #expect(host.draw(in: scene))
    let rendered = try #require(host.renderLayer)
    #expect(rendered.sublayers.map(ObjectIdentifier.init) == [content, try #require(above.renderLayer)].map(ObjectIdentifier.init), "above the drawing, below the sublayers")
    // Sublayers come and go; what the owner drew in its layer stays.
    above.removeFromSuperlayer()
    #expect(host.draw(in: scene))
    #expect(rendered.sublayers.map(ObjectIdentifier.init) == [ObjectIdentifier(content)])
    #expect(content.sublayers.map(ObjectIdentifier.init) == [ObjectIdentifier(drawn)])
    host._irisContentLayer = nil
    #expect(host.draw(in: scene))
    #expect(rendered.sublayers.isEmpty)
}

@MainActor @Test func windowsLeaveTheSceneLayersTheyDidNotAdd() throws {
    makeScene()
    let foreign = IrisRender.Layer(in: irisScene)
    irisScene.root.addSublayer(foreign)
    defer { foreign.removeFromSuperlayer() }
    let screen = Screen()
    LayerCommit.commit()
    let window = try #require(screen.window.layer.renderLayer.map(ObjectIdentifier.init))
    #expect(irisScene.root.sublayers.map(ObjectIdentifier.init).contains(window))
    screen.close()
    LayerCommit.commit()
    let left = irisScene.root.sublayers.map(ObjectIdentifier.init)
    #expect(left.contains(ObjectIdentifier(foreign)) && !left.contains(window))
}

/// A view that takes the host's input on its own while it is first responder, as a hosting
/// view does for SwiftUI's text fields.
@MainActor
private final class Handler: UIView, @preconcurrency DeviceInputHandler {
    var log: [String] = []
    var wantsKeyboard = true

    override var canBecomeFirstResponder: Bool {
        wantsKeyboard
    }

    override func resignFirstResponder() -> Bool {
        log.append("resign")
        return super.resignFirstResponder()
    }

    func touch(_ touches: [DeviceTouch], at time: TimeInterval) {}
    func commit(_ text: String) { log.append("commit \(text)") }
    func compose(_ text: String) { log.append("compose \(text)") }
    func deleteSurrounding(before: Int, after: Int) { log.append("delete \(before) \(after)") }
    func press(_ code: String, command: Bool) { log.append("press \(code)") }
}

@MainActor @Test func inputGoesToWhicheverSideHasTheKeyboard() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let handler = Handler(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
    let field = UITextField(frame: CGRect(x: 20, y: 400, width: 300, height: 34))
    screen.root.addSubview(handler)
    screen.root.addSubview(field)
    #expect(handler.becomeFirstResponder())
    screen.input.compose("ơ")
    screen.input.commit("ơi")
    screen.input.deleteSurrounding(before: 1, after: 0)
    screen.input.press("Enter", command: false)
    #expect(handler.log == ["compose ơ", "commit ơi", "delete 1 0", "press Enter"])
    #expect(field.text == "")
    // UIKit's field taking the keyboard makes the handler resign; input goes to the field.
    #expect(field.becomeFirstResponder())
    screen.input.commit("à")
    #expect(handler.log.last == "resign" && field.text == "à")
    // And back.
    #expect(handler.becomeFirstResponder() && !field.isFirstResponder)
    screen.input.commit("x")
    #expect(handler.log.last == "commit x" && field.text == "à")
}

@MainActor @Test func childViewControllersHearOfTheirParent() {
    final class Child: UIViewController {
        var log: [String] = []
        override func willMove(toParent parent: UIViewController?) {
            log.append("will \(parent == nil ? "leave" : "join")")
        }
        override func didMove(toParent parent: UIViewController?) {
            log.append("did \(parent == nil ? "leave" : "join")")
        }
        override func viewDidLayoutSubviews() {
            log.append("laid out")
        }
    }
    let parent = UIViewController()
    let child = Child()
    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)
    #expect(parent.children == [child] && child.parent === parent)
    child.view.layoutIfNeeded()
    #expect(child.log.last == "laid out")
    child.log.removeLast()
    #expect(child.view.next === child && child.next === parent.view, "the responder chain goes through the container's view")
    child.willMove(toParent: nil)
    child.view.removeFromSuperview()
    child.removeFromParent()
    #expect(parent.children.isEmpty && child.parent == nil)
    #expect(child.log == ["will join", "did join", "will leave", "did leave"])
}

// What a SwiftUI view of a UIViewRepresentable relies on: drawing the UIKit view at its place
// among SwiftUI's content, and hearing when its size changes.

@Test func ownedLayersDrawInTheirOwnersLayer() throws {
    let scene = IrisRender.Scene(width: 390, height: 844, scale: 1)
    let host = CALayer()
    host.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
    let embedded = CALayer()
    embedded.frame = CGRect(x: 20, y: 30, width: 100, height: 50)
    let inside = CALayer()
    embedded.addSublayer(inside)
    let sibling = CALayer()
    host.addSublayer(embedded)
    host.addSublayer(sibling)
    // A layer of SwiftUI's content, in the host's coordinates.
    let slot = IrisRender.Layer(in: scene)
    embedded._irisOwnerLayer = slot
    #expect(host.draw(in: scene))
    let rendered = try #require(host.renderLayer)
    let embeddedLayer = try #require(embedded.renderLayer)
    #expect(rendered.sublayers.map(ObjectIdentifier.init) == [try #require(sibling.renderLayer)].map(ObjectIdentifier.init), "the host leaves it out")
    #expect(slot.sublayers.map(ObjectIdentifier.init) == [ObjectIdentifier(embeddedLayer)])
    #expect(embeddedLayer.frame == Rect(x: 20, y: 30, width: 100, height: 50), "placed in the host's coordinates")
    #expect(embeddedLayer.sublayers.count == 1, "its own sublayers draw as ever")
    // The host's sublayers change: the owned layer stays with its owner.
    host.addSublayer(CALayer())
    #expect(host.draw(in: scene))
    #expect(slot.sublayers.map(ObjectIdentifier.init) == [ObjectIdentifier(embeddedLayer)])
    #expect(rendered.sublayers.count == 2)
    // A new owner, then none: the host takes the layer back, in its place among its sublayers.
    let next = IrisRender.Layer(in: scene)
    embedded._irisOwnerLayer = next
    #expect(host.draw(in: scene))
    #expect(slot.sublayers.isEmpty && next.sublayers.map(ObjectIdentifier.init) == [ObjectIdentifier(embeddedLayer)])
    embedded._irisOwnerLayer = nil
    #expect(host.draw(in: scene))
    #expect(next.sublayers.isEmpty && rendered.sublayers.first.map(ObjectIdentifier.init) == ObjectIdentifier(embeddedLayer))
}

@MainActor @Test func superviewsHearOfIntrinsicSizeChanges() {
    final class Host: UIView {
        var changed: [UIView] = []
        override func _intrinsicContentSizeInvalidated(forChildView view: UIView) {
            changed.append(view)
        }
    }
    let host = Host()
    let label = UILabel()
    host.addSubview(label)
    label.text = "Xin chào"
    #expect(host.changed.first === label)
    // Content priorities, by default as in UIKit: hug weakly, resist compression strongly.
    #expect(label.contentHuggingPriority(for: .horizontal) == .defaultLow)
    #expect(label.contentCompressionResistancePriority(for: .vertical) == .defaultHigh)
    label.setContentHuggingPriority(.required, for: .vertical)
    #expect(label.contentHuggingPriority(for: .vertical) == .required && label.contentHuggingPriority(for: .horizontal) == .defaultLow)
    #expect(UILayoutPriority.defaultHigh + 1 > .defaultHigh && UILayoutPriority(999) < .required)
}
