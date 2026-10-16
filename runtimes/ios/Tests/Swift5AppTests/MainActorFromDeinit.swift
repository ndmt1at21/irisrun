import Testing
import UIKit

// Built as an app's code is: Swift 5 language mode, with `import UIKit` aliased to OpenUIKit.
// UIKit's main-actor API is `@preconcurrency`, as the iOS SDK's is to Swift 5 apps, so this
// compiles. Without it, the deinit and the nonisolated method below are errors (seen in the
// corpus app zlgithubclient's ZLAssistButtonManager).

/// Not isolated, as an NSObject subclass of an app is, yet it owns and changes views.
final class FloatingButtonManager: NSObject {
    let button = UIButton(type: .system)

    deinit {
        button.isHidden = true
        button.removeFromSuperview()
    }

    func show(in view: UIView) {
        view.addSubview(button)
        button.setTitle("Help", for: .normal)
    }
}

@MainActor @Test func swift5AppsUseMainActorUIKitFromAnywhere() {
    let window = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    var manager: FloatingButtonManager? = FloatingButtonManager()
    manager?.show(in: window)
    #expect(window.subviews.count == 1)
    manager = nil
    #expect(window.subviews.isEmpty)
}
