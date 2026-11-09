import UIKit

final class FlexRootOrchestrator {
    static let shared = FlexRootOrchestrator()

    private init() {}

    var keyWindow: UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first
    }

    func bootstrap(in window: UIWindow) {
        window.rootViewController = FlexDockShell()
        window.makeKeyAndVisible()
    }

    /// Guest / require-login: modal over dock. Sign-out / session wipe: replace root so old home cache is gone.
    func presentGate(replaceRoot: Bool = false) {
        guard let window = keyWindow else { return }
        if replaceRoot || !(window.rootViewController is FlexDockShell) {
            window.rootViewController = UINavigationController(rootViewController: GateCanvas())
            window.makeKeyAndVisible()
            return
        }
        FlexLoginGate.presentLogin(from: window.rootViewController)
    }

    func presentDock() {
        guard let window = keyWindow else { return }
        window.rootViewController = FlexDockShell()
        window.makeKeyAndVisible()
    }

    func popToHub() {
        guard let dock = keyWindow?.rootViewController as? FlexDockShell else { return }
        dock.selectTab(index: 0)
    }

    /// Success Confirm / similar: land on home tab with empty navigation stacks.
    func returnToHubHome() {
        guard let dock = keyWindow?.rootViewController as? FlexDockShell else { return }
        dock.viewControllers?.forEach { controller in
            (controller as? UINavigationController)?.popToRootViewController(animated: false)
        }
        dock.selectTab(index: 0)
    }

    func openLedger(tab: LedgerTabKind) {
        LedgerOrdersLaunch.pendingTab = tab
        NotificationCenter.default.post(name: .flexOpenLedgerTab, object: tab)
        guard let dock = keyWindow?.rootViewController as? FlexDockShell else { return }
        dock.selectTab(index: 1)
    }
}
