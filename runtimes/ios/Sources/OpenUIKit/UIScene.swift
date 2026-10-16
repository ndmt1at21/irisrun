import Foundation

/// One instance of the app's UI. Iris connects one window scene at launch.
@preconcurrency @MainActor
open class UIScene: UIResponder {
    public init(session: UISceneSession, connectionOptions: UIScene.ConnectionOptions) {
        self.session = session
        super.init()
    }

    open private(set) var session: UISceneSession

    open var delegate: (any UISceneDelegate)?

    open internal(set) var activationState = UIScene.ActivationState.unattached

    open var title: String!

    override open var next: UIResponder? {
        UIApplication.shared
    }
}

extension UIScene {
    public enum ActivationState: Int, Sendable {
        case unattached = -1
        case foregroundActive = 0
        case foregroundInactive = 1
        case background = 2
    }

    /// Why a scene connected, such as a URL to open.
    // ponytail: empty until URLs, shortcuts and user activities reach apps.
    @preconcurrency @MainActor
    open class ConnectionOptions: NSObject {
        override init() {
            super.init()
        }
    }
}

/// A scene that shows windows.
@preconcurrency @MainActor
open class UIWindowScene: UIScene {
    open var screen: UIScreen {
        .main
    }

    open var windows: [UIWindow] {
        attachedWindows.compactMap(\.window)
    }

    open var keyWindow: UIWindow? {
        windows.first { $0.isKeyWindow }
    }

    var attachedWindows: [WeakWindow] = []
}

/// What a scene tells about its life. Every method is optional.
@preconcurrency @MainActor
public protocol UISceneDelegate: NSObjectProtocol {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    func sceneDidDisconnect(_ scene: UIScene)
    func sceneDidBecomeActive(_ scene: UIScene)
    func sceneWillResignActive(_ scene: UIScene)
    func sceneWillEnterForeground(_ scene: UIScene)
    func sceneDidEnterBackground(_ scene: UIScene)
}

extension UISceneDelegate {
    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {}
    public func sceneDidDisconnect(_ scene: UIScene) {}
    public func sceneDidBecomeActive(_ scene: UIScene) {}
    public func sceneWillResignActive(_ scene: UIScene) {}
    public func sceneWillEnterForeground(_ scene: UIScene) {}
    public func sceneDidEnterBackground(_ scene: UIScene) {}
}

@preconcurrency @MainActor
public protocol UIWindowSceneDelegate: UISceneDelegate {
    var window: UIWindow? { get set }
}

extension UIWindowSceneDelegate {
    public var window: UIWindow? {
        get { nil }
        set {}
    }
}

/// A scene's place in the app, which outlives the scene.
@preconcurrency @MainActor
open class UISceneSession: NSObject {
    init(role: UISceneSession.Role, configuration: UISceneConfiguration) {
        self.role = role
        self.configuration = configuration
        super.init()
    }

    open internal(set) weak var scene: UIScene?
    open private(set) var role: UISceneSession.Role
    open internal(set) var configuration: UISceneConfiguration
    open private(set) var persistentIdentifier = UUID().uuidString
    open var userInfo: [String: Any]?
}

extension UISceneSession {
    public struct Role: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public static let windowApplication = Role("UIWindowSceneSessionRoleApplication")
        public static let windowExternalDisplayNonInteractive = Role("UIWindowSceneSessionRoleExternalDisplayNonInteractive")
    }
}

/// Which scene and delegate classes make a scene.
@preconcurrency @MainActor
open class UISceneConfiguration: NSObject {
    /// Takes the scene class, delegate class and storyboard from the configuration with this
    /// name and role in the app's Info.plist, if there is one.
    public convenience init(name: String?, sessionRole: UISceneSession.Role) {
        self.init(name: name, sessionRole: sessionRole, info: Bundle.main.infoDictionary ?? [:])
    }

    init(name: String?, sessionRole: UISceneSession.Role, info: [String: Any]) {
        self.name = name
        role = sessionRole
        super.init()
        guard let entry = Self.manifestEntries(for: sessionRole, in: info).first(where: { name != nil && $0["UISceneConfigurationName"] as? String == name }) else {
            return
        }
        sceneClass = (entry["UISceneClassName"] as? String).flatMap(NSClassFromString)
        delegateClass = (entry["UISceneDelegateClassName"] as? String).flatMap(NSClassFromString)
        storyboardName = entry["UISceneStoryboardFile"] as? String
    }

    open private(set) var name: String?
    open private(set) var role: UISceneSession.Role
    open var sceneClass: AnyClass?
    open var delegateClass: AnyClass?
    /// ponytail: a name until UIStoryboard comes (P1-16, step 6).
    var storyboardName: String?

    /// The first configuration for a role in the app's Info.plist.
    static func first(for role: UISceneSession.Role, in info: [String: Any] = Bundle.main.infoDictionary ?? [:]) -> UISceneConfiguration {
        let name = manifestEntries(for: role, in: info).first?["UISceneConfigurationName"] as? String
        return UISceneConfiguration(name: name, sessionRole: role, info: info)
    }

    /// The configurations of a role in an Info.plist's `UIApplicationSceneManifest`.
    static func manifestEntries(for role: UISceneSession.Role, in info: [String: Any]) -> [[String: Any]] {
        let manifest = info["UIApplicationSceneManifest"] as? [String: Any]
        let configurations = manifest?["UISceneConfigurations"] as? [String: Any]
        return configurations?[role.rawValue] as? [[String: Any]] ?? []
    }
}
