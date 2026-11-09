import UIKit

enum FlexLoginGate {
    static var isLoggedIn: Bool { CofferVault.shared.isLoggedIn }

    @discardableResult
    static func requireLogin(from host: UIViewController?) -> Bool {
        guard !isLoggedIn else { return true }
        presentLogin(from: host)
        return false
    }

    static func presentLogin(from host: UIViewController?) {
        let root = host ?? FlexRootOrchestrator.shared.keyWindow?.rootViewController
        guard let presenter = topMost(from: root) else { return }
        if presenter is GateCanvas { return }
        if let nav = presenter as? UINavigationController, nav.viewControllers.first is GateCanvas { return }
        if let presented = presenter.presentedViewController {
            if presented is GateCanvas { return }
            if let nav = presented as? UINavigationController, nav.viewControllers.first is GateCanvas { return }
        }

        let gate = GateCanvas()
        let nav = UINavigationController(rootViewController: gate)
        nav.modalPresentationStyle = .fullScreen
        nav.setNavigationBarHidden(true, animated: false)
        presenter.present(nav, animated: true)
    }

    static func handleLoginSuccess(from gate: GateCanvas) {
        let showHome = {
            FlexRootOrchestrator.shared.presentDock()
            // Defer so new `MintHubCanvas.viewDidLoad` can register before the refresh ping.
            DispatchQueue.main.async {
                notifyLoggedIn()
            }
        }
        if let presentedNavigation = gate.navigationController,
           presentedNavigation.presentingViewController != nil {
            presentedNavigation.dismiss(animated: true, completion: showHome)
        } else if gate.presentingViewController != nil {
            gate.dismiss(animated: true, completion: showHome)
        } else {
            showHome()
        }
    }

    private static func notifyLoggedIn() {
        NotificationCenter.default.post(name: .flexSessionDidLogin, object: nil)
    }

    private static func topMost(from controller: UIViewController?) -> UIViewController? {
        guard var current = controller else { return nil }
        while let presented = current.presentedViewController {
            current = presented
        }
        if let tab = current as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        if let nav = current as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        return current
    }
}

extension Notification.Name {
    static let flexSessionDidLogin = Notification.Name("flex.session.didLogin")
}
