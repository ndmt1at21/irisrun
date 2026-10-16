import Foundation
import IrisHost

/// The backdrop of an app's views. A window shows once it is made visible, in its scene's
/// screen; Iris has one screen, the phone's (`UIScreen`).
@preconcurrency @MainActor
open class UIWindow: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
    }

    public init(windowScene: UIWindowScene) {
        super.init(frame: windowScene.screen.bounds)
        isHidden = true
        self.windowScene = windowScene
        // An initializer setting its own class's property runs no observer.
        windowScene.attachedWindows.append(WeakWindow(window: self))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        isHidden = true
    }

    open weak var windowScene: UIWindowScene? {
        didSet {
            oldValue?.attachedWindows.removeAll { $0.window === self }
            windowScene?.attachedWindows.append(WeakWindow(window: self))
        }
    }

    open var screen: UIScreen {
        windowScene?.screen ?? .main
    }

    open var windowLevel = UIWindow.Level.normal {
        didSet { UIWindow.update(self) }
    }

    override open var isHidden: Bool {
        didSet { UIWindow.update(self) }
    }

    override open var next: UIResponder? {
        windowScene ?? UIApplication.shared
    }

    /// The phone's in portrait, for a window that covers the screen: below the status bar or
    /// the Dynamic Island, above the home indicator (47 and 34 points on an iPhone 14, 20 and
    /// none on an iPhone SE).
    override open var safeAreaInsets: UIEdgeInsets {
        let phone = IrisScreen.current, screen = self.screen.bounds
        return UIEdgeInsets(top: max(0, phone.safeTop - frame.minY), left: 0, bottom: max(0, frame.maxY - (screen.maxY - phone.safeBottom)), right: 0)
    }

    /// Delivers the event's touches in this window: to gesture recognizers first, then to
    /// the views they began in.
    open func sendEvent(_ event: UIEvent) {
        guard event.type == .touches, let touches = event.touches(for: self), !touches.isEmpty else { return }
        GestureEnvironment.deliver(touches, with: event)
    }

    // MARK: Key window

    /// The window that takes keyboard and other non-touch events.
    static weak var key: UIWindow?

    open var isKeyWindow: Bool {
        UIWindow.key === self
    }

    open var canBecomeKey: Bool {
        true
    }

    open func makeKey() {
        guard UIWindow.key !== self, canBecomeKey else { return }
        let old = UIWindow.key
        UIWindow.key = self
        old?.resignKey()
        becomeKey()
    }

    open func makeKeyAndVisible() {
        isHidden = false
        makeKey()
    }

    open func becomeKey() {}

    open func resignKey() {}

    // MARK: Root view controller

    /// The view controller whose view fills the window. A new one takes the old one's place, the
    /// old disappearing and the new appearing, as in UIKit.
    open var rootViewController: UIViewController? {
        didSet {
            guard rootViewController !== oldValue else { return }
            let old = oldValue?.viewIfLoaded?.superview === self ? oldValue : nil
            UIViewController.irisTransition(from: old.map { [$0] } ?? [], to: isHidden ? [] : rootViewController.map { [$0] } ?? [], animated: false, prepare: {
                old?.view.removeFromSuperview()
                self.installRootView()
            })
        }
    }

    /// Puts the root view controller's view in the window, filling it, once the window shows.
    private func installRootView() {
        guard !isHidden, let controller = rootViewController else { return }
        let view: UIView = controller.view
        guard view.superview !== self else { return }
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
    }

    /// The root view controller appears as the window shows, and disappears as it hides.
    private func rootVisibilityChanged() {
        guard let controller = rootViewController else { return }
        UIViewController.irisTransition(from: isHidden ? [controller] : [], to: isHidden ? [] : [controller], animated: false, prepare: installRootView)
    }

    // MARK: Iris: the screen

    /// The windows on screen, back to front.
    // ponytail: kept while visible, whether or not the app keeps the window; on iOS a window
    // nothing else keeps goes away.
    static var visible: [UIWindow] = []

    /// The screen became another phone's: windows that filled it fill it again, and what is in
    /// them lays out anew, as when a scene's size changes.
    static func screenDidChange(from old: IrisScreen) {
        for window in visible where window.frame == CGRect(origin: .zero, size: old.size) {
            window.frame = UIScreen.main.bounds
        }
    }

    /// Puts a window on screen by its level, or takes it off.
    private static func update(_ window: UIWindow) {
        let before = visible.map(ObjectIdentifier.init)
        let wasVisible = before.contains(ObjectIdentifier(window))
        visible.removeAll { $0 === window }
        if !window.isHidden {
            let index = visible.firstIndex { $0.windowLevel.rawValue > window.windowLevel.rawValue } ?? visible.count
            visible.insert(window, at: index)
        }
        if wasVisible == window.isHidden {
            window.rootVisibilityChanged()
        }
        if visible.map(ObjectIdentifier.init) != before {
            LayerCommit.roots = visible.map(\.layer)
        }
    }
}

struct WeakWindow {
    weak var window: UIWindow?
}

extension UIWindow {
    /// Where a window stacks among the others.
    public struct Level: RawRepresentable, Hashable, Sendable {
        public let rawValue: CGFloat

        public init(rawValue: CGFloat) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: CGFloat) {
            self.rawValue = rawValue
        }

        public static let normal = Level(0)
        public static let statusBar = Level(1000)
        public static let alert = Level(2000)
    }
}
