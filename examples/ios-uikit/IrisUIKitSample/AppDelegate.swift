import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Lifecycle.record("launch")
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // The delegate class comes from the configuration of this name in Info.plist.
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

/// The lifecycle callbacks so far, shown on screen so that a run can check their order.
@MainActor
enum Lifecycle {
    private(set) static var events: [String] = []
    static var onChange: ((String) -> Void)?

    static func record(_ event: String) {
        events.append(event)
        onChange?(events.joined(separator: " → "))
    }
}
