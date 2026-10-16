import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        Lifecycle.record("connect")
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Lifecycle.record("foreground")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Lifecycle.record("active")
    }
}
