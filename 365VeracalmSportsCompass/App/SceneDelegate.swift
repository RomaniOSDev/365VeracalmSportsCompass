import UIKit
import StartAppKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var startAppResolver: StartAppResolver?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        startAppResolver = StartAppResolver(window: window, configuration: .app)
        window?.rootViewController = startAppResolver?.resolveEntryViewController()
        window?.makeKeyAndVisible()
    }
}
