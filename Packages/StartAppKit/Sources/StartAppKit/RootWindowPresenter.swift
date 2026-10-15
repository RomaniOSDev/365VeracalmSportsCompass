import UIKit

final class RootWindowPresenter {

    private weak var window: UIWindow?

    init(window: UIWindow?) {
        self.window = window
    }

    func crossfade(to viewController: UIViewController, duration: TimeInterval = 0.3) {
        guard let window else { return }
        UIView.transition(with: window, duration: duration, options: .transitionCrossDissolve, animations: {
            window.rootViewController = viewController
        })
    }
}
