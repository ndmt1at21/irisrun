import Foundation
import IrisRender
@testable import OpenUIKit
import Testing

@Test func autoresizingSharesTheChangeAmongTheFlexibleParts() {
    let frame = CGRect(x: 20, y: 10, width: 100, height: 40)
    let old = CGSize(width: 150, height: 100)
    let new = CGSize(width: 210, height: 160)
    #expect(UIView.AutoresizingMask.flexibleWidth.resizing(frame, from: old, to: new) == CGRect(x: 20, y: 10, width: 160, height: 40))
    // Margin and width in proportion to their lengths, 20 and 100.
    #expect(UIView.AutoresizingMask([.flexibleLeftMargin, .flexibleWidth]).resizing(frame, from: old, to: new) == CGRect(x: 30, y: 10, width: 150, height: 40))
    // Both margins keep the view where it was in proportion: centered stays centered.
    let centered = CGRect(x: 25, y: 10, width: 100, height: 40)
    #expect(UIView.AutoresizingMask([.flexibleLeftMargin, .flexibleRightMargin]).resizing(centered, from: old, to: new).midX == 105)
    // Height 40 and bottom margin 40 share the 60 points evenly.
    #expect(UIView.AutoresizingMask([.flexibleHeight, .flexibleBottomMargin]).resizing(frame, from: CGSize(width: 150, height: 90), to: CGSize(width: 150, height: 150)) == CGRect(x: 20, y: 10, width: 100, height: 70))
    #expect(UIView.AutoresizingMask().resizing(frame, from: old, to: new) == frame)
}

@MainActor @Test func subviewsAutoresizeWhenTheirSuperviewDoes() {
    let superview = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let bar = UIView(frame: CGRect(x: 10, y: 10, width: 180, height: 20))
    bar.autoresizingMask = [.flexibleWidth]
    let pinned = UIView(frame: CGRect(x: 150, y: 50, width: 40, height: 40))
    pinned.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
    superview.addSubview(bar)
    superview.addSubview(pinned)
    superview.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
    #expect(bar.frame == CGRect(x: 10, y: 10, width: 370, height: 20))
    #expect(pinned.frame == CGRect(x: 340, y: 150, width: 40, height: 40))
    superview.autoresizesSubviews = false
    superview.frame.size.width = 100
    #expect(bar.frame.width == 370)
}

@MainActor @Test func convertsAndHitTestsThroughTransforms() {
    let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let card = UIView(frame: CGRect(x: 100, y: 100, width: 100, height: 50))
    let inner = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
    root.addSubview(card)
    card.addSubview(inner)
    #expect(inner.convert(CGPoint(x: 5, y: 5), to: nil) == CGPoint(x: 115, y: 115))
    #expect(root.hitTest(CGPoint(x: 115, y: 115), with: nil) === inner)
    // A quarter turn about the card's center, (150, 125): inner's center, 30 left of and 5
    // above it, ends up 5 right of and 30 above it.
    card.transform = CGAffineTransform(rotationAngle: .pi / 2)
    let center = inner.convert(CGPoint(x: 10, y: 10), to: nil)
    #expect(abs(center.x - 155) < 1e-9 && abs(center.y - 95) < 1e-9)
    #expect(abs(card.frame.width - 50) < 1e-9 && abs(card.frame.height - 100) < 1e-9)
    #expect(root.hitTest(CGPoint(x: 155, y: 95), with: nil) === inner)
    #expect(inner.convert(CGPoint(x: 155, y: 95), from: nil).x.rounded() == 10)
    card.isHidden = true
    #expect(root.hitTest(CGPoint(x: 155, y: 95), with: nil) === root)
}

@Test func layersSendOnlyWhatChanged() throws {
    let scene = IrisRender.Scene(width: 390, height: 844, scale: 1)
    let root = CALayer()
    root.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let child = CALayer()
    child.frame = CGRect(x: 10, y: 40, width: 100, height: 50)
    root.addSublayer(child)
    #expect(root.draw(in: scene), "everything, the first time")
    #expect(!root.draw(in: scene), "nothing changed")
    let rendered = try #require(child.renderLayer)
    #expect(rendered.frame == Rect(x: 10, y: 40, width: 100, height: 50))
    #expect(root.renderLayer?.sublayers.first === rendered)

    child.backgroundColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    child.shadowOpacity = 0.5
    #expect(child.changes == .style)
    #expect(root.draw(in: scene))
    #expect(rendered.backgroundColor == 0xFFFF_0000)
    #expect(rendered.shadowColor == 0x8000_0000, "black at half the opacity")
    #expect(rendered.shadowOffset == Point(x: 0, y: -3))

    // Sublayers sit relative to the origin of the bounds, as when scrolling.
    root.bounds.origin.y = 30
    #expect(root.draw(in: scene))
    #expect(rendered.frame == Rect(x: 10, y: 10, width: 100, height: 50))

    // The render core turns layers about their centers; Core Animation about the anchor point.
    child.anchorPoint = .zero
    child.position = CGPoint(x: 10, y: 40)
    child.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 2))
    #expect(root.draw(in: scene))
    let t = rendered.transform.map { ($0 * 1000).rounded() / 1000 }
    #expect(t == [0, 1, -1, 0, -75, 25])

    child.removeFromSuperlayer()
    #expect(root.draw(in: scene))
    #expect(root.renderLayer?.sublayers.isEmpty == true)
}

final class TestSceneDelegate: UIResponder, UIWindowSceneDelegate {}

@MainActor @Test func sceneConfigurationsComeFromTheInfoPlist() {
    let info: [String: Any] = [
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [
                "UIWindowSceneSessionRoleApplication": [
                    [
                        "UISceneConfigurationName": "Default Configuration",
                        "UISceneDelegateClassName": "OpenUIKitTests.TestSceneDelegate",
                    ],
                ],
            ],
        ],
    ]
    let configuration = UISceneConfiguration.first(for: .windowApplication, in: info)
    #expect(configuration.name == "Default Configuration")
    #expect(configuration.delegateClass == TestSceneDelegate.self)
    #expect(UISceneConfiguration(name: "Other", sessionRole: .windowApplication, info: info).delegateClass == nil)
    #expect(UISceneConfiguration.first(for: .windowApplication, in: [:]).delegateClass == nil)
}

@MainActor @Test func windowsJoinTheirScene() {
    let role = UISceneSession.Role.windowApplication
    let session = UISceneSession(role: role, configuration: UISceneConfiguration(name: nil, sessionRole: role, info: [:]))
    let scene = UIWindowScene(session: session, connectionOptions: UIScene.ConnectionOptions())
    let window = UIWindow(windowScene: scene)
    #expect(scene.windows == [window])
    #expect(window.frame == UIScreen.main.bounds && window.isHidden)
    let other = UIWindow(frame: .zero)
    other.windowScene = scene
    window.windowScene = nil
    #expect(scene.windows == [other])
}

@MainActor @Test func viewControllersLoadTheirViewWhenAskedFor() {
    final class Controller: UIViewController {
        var loads = 0
        override func viewDidLoad() {
            loads += 1
        }
    }
    let controller = Controller()
    #expect(!controller.isViewLoaded)
    #expect(controller.view.frame == UIScreen.main.bounds)
    _ = controller.view
    #expect(controller.loads == 1)
    #expect(controller.view.next === controller)
}

@Test func colorsConvertBetweenModels() {
    var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    let orange = UIColor(red: 1, green: 0.6, blue: 0, alpha: 1)
    #expect(orange.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha))
    #expect(abs(hue * 360 - 36) < 1e-9 && saturation == 1 && brightness == 1)
    #expect(UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha).cgColor.argb == orange.cgColor.argb)
    #expect(UIColor.systemBlue.cgColor.argb == 0xFF00_7AFF)
    #expect(UIColor.white.withAlphaComponent(0.5).cgColor.argb == 0x80FF_FFFF)
    var white: CGFloat = 0
    #expect(!orange.getWhite(&white, alpha: nil))
}
