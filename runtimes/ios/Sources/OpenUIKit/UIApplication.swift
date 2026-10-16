import Foundation
import IrisHost

/// The running app. `UIApplicationMain`, or `@main` on the app delegate, makes it and runs it.
@preconcurrency @MainActor
open class UIApplication: UIResponder {
    private static var current: UIApplication?

    open class var shared: UIApplication {
        if let current { return current }
        // Apps on OpenSwiftUI have no UIKit launch; they get one too.
        let application = UIApplication()
        current = application
        return application
    }

    public override init() {
        super.init()
    }

    open var delegate: (any UIApplicationDelegate)?

    open internal(set) var applicationState = UIApplication.State.inactive

    open internal(set) var connectedScenes: Set<UIScene> = []

    open var openSessions: Set<UISceneSession> {
        Set(connectedScenes.map(\.session))
    }

    open var supportsMultipleScenes: Bool {
        false
    }

    /// The windows on screen.
    open var windows: [UIWindow] {
        UIWindow.visible
    }

    open var keyWindow: UIWindow? {
        UIWindow.key
    }

    open var isIdleTimerDisabled = false

    override open var next: UIResponder? {
        delegate as? UIResponder
    }

    // MARK: Events and actions

    /// Sends an event to the windows of its touches.
    open func sendEvent(_ event: UIEvent) {
        var windows: [UIWindow] = []
        for touch in (event.allTouches ?? []).sorted(by: { $0.number < $1.number }) {
            if let window = touch.window, !windows.contains(window) {
                windows.append(window)
            }
        }
        for window in windows {
            window.sendEvent(event)
        }
    }

    /// Sends an action to `target`, or for nil, to the first responder that can perform it,
    /// from the first responder up, or from the sender when there is none. False if no
    /// responder could; a target without the method stops the app, as on iOS.
    @discardableResult
    open func sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let receiver: AnyObject
        if let target {
            receiver = target as AnyObject
        } else if let found = (UIResponder.first ?? sender as? UIResponder)?.target(forAction: action, withSender: sender) {
            receiver = found as AnyObject
        } else {
            return false
        }
        _IrisMethods.send(action, to: receiver, with: [sender, event])
        return true
    }
}

extension UIApplication {
    public enum State: Int, Sendable {
        case active = 0
        case inactive = 1
        case background = 2
    }

    public struct LaunchOptionsKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    nonisolated public static let didFinishLaunchingNotification = NSNotification.Name("UIApplicationDidFinishLaunchingNotification")
    nonisolated public static let didBecomeActiveNotification = NSNotification.Name("UIApplicationDidBecomeActiveNotification")
    nonisolated public static let willResignActiveNotification = NSNotification.Name("UIApplicationWillResignActiveNotification")
    nonisolated public static let didEnterBackgroundNotification = NSNotification.Name("UIApplicationDidEnterBackgroundNotification")
    nonisolated public static let willEnterForegroundNotification = NSNotification.Name("UIApplicationWillEnterForegroundNotification")
    nonisolated public static let willTerminateNotification = NSNotification.Name("UIApplicationWillTerminateNotification")
}

/// What the app tells its delegate about its life. Every method is optional.
@preconcurrency @MainActor
public protocol UIApplicationDelegate: NSObjectProtocol {
    /// The app's window, for apps without scenes.
    var window: UIWindow? { get set }
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    func applicationDidBecomeActive(_ application: UIApplication)
    func applicationWillResignActive(_ application: UIApplication)
    func applicationDidEnterBackground(_ application: UIApplication)
    func applicationWillEnterForeground(_ application: UIApplication)
    func applicationWillTerminate(_ application: UIApplication)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>)
}

extension UIApplicationDelegate {
    public var window: UIWindow? {
        get { nil }
        set {}
    }

    public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {}
    public func applicationWillResignActive(_ application: UIApplication) {}
    public func applicationDidEnterBackground(_ application: UIApplication) {}
    public func applicationWillEnterForeground(_ application: UIApplication) {}
    public func applicationWillTerminate(_ application: UIApplication) {}

    /// The first configuration for the session's role in the app's Info.plist, as UIKit takes
    /// when the delegate has none to give.
    public func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        .first(for: connectingSceneSession.role)
    }

    public func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    /// Runs the app with this delegate, for `@main` on the delegate class.
    public static func main() {
        UIApplication.run(principalClass: nil, delegateClass: Self.self)
    }
}

/// Makes the app object and its delegate, of classes named as `NSStringFromClass` names them,
/// and runs the app. It never returns.
@discardableResult
public func UIApplicationMain(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
    _ principalClassName: String?,
    _ delegateClassName: String?
) -> Int32 {
    MainActor.assumeIsolated {
        UIApplication.run(
            principalClass: principalClassName.flatMap(NSClassFromString),
            delegateClass: delegateClassName.flatMap(NSClassFromString)
        )
    }
}

// MARK: - Launch

extension UIApplication {
    /// Launches the app as iOS does, then shows it on the device or plays a script.
    static func run(principalClass: AnyClass?, delegateClass: AnyClass?) -> Never {
        let host = UIKitHost.start()
        let application = principalClass.flatMap { instantiate($0) as? UIApplication } ?? UIApplication()
        current = application
        let delegate = delegateClass.flatMap { instantiate($0) as? any UIApplicationDelegate }
        application.delegate = delegate
        _ = delegate?.application(application, willFinishLaunchingWithOptions: nil)
        _ = delegate?.application(application, didFinishLaunchingWithOptions: nil)
        NotificationCenter.default.post(name: didFinishLaunchingNotification, object: application)

        // Apps with a scene manifest live in scenes; the rest in the delegate's window.
        if Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") != nil {
            application.connectScene()
        } else {
            application.applicationState = .active
            delegate?.applicationDidBecomeActive(application)
        }
        NotificationCenter.default.post(name: didBecomeActiveNotification, object: application)
        host.run()
    }

    /// Connects the app's one window scene and brings it to the foreground.
    private func connectScene() {
        let role = UISceneSession.Role.windowApplication
        let options = UIScene.ConnectionOptions()
        let session = UISceneSession(role: role, configuration: .first(for: role))
        let configuration = delegate?.application(self, configurationForConnecting: session, options: options) ?? session.configuration
        session.configuration = configuration
        // ponytail: always a UIWindowScene; subclasses of it are rare.
        let scene = UIWindowScene(session: session, connectionOptions: options)
        session.scene = scene
        scene.delegate = configuration.delegateClass.flatMap { instantiate($0) as? any UISceneDelegate }
        if let storyboard = configuration.storyboardName {
            printError("irisrun: storyboard \(storyboard) is not read yet (P1-16, step 6)")
        }
        connectedScenes.insert(scene)
        scene.activationState = .foregroundInactive
        scene.delegate?.scene(scene, willConnectTo: session, options: options)
        scene.delegate?.sceneWillEnterForeground(scene)
        scene.activationState = .foregroundActive
        applicationState = .active
        scene.delegate?.sceneDidBecomeActive(scene)
    }
}
