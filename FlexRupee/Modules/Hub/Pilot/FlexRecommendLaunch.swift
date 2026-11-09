import UIKit

enum FlexRecommendLaunch {
    private static var inFlight = false

    /// Present matching page. Blocked while a recommend request is still in-flight.
    static func open(from host: UIViewController,
                     autoOrder: Bool,
                     onFinished: (() -> Void)? = nil,
                     onPlaced: ((String, String) -> Void)? = nil) {
        guard !inFlight else {
            onFinished?()
            return
        }
        guard let nav = host.navigationController else {
            onFinished?()
            return
        }
        inFlight = true
        _ = autoOrder
        _ = onPlaced
        let canvas = FlexRecommendMatchCanvas()
        canvas.onFinished = {
            inFlight = false
            onFinished?()
        }
        canvas.hidesBottomBarWhenPushed = true
        // No push animation — matching page appears instantly.
        nav.pushViewController(canvas, animated: false)
    }

    static func markIdle() {
        inFlight = false
    }

    static func replaceTop(of nav: UINavigationController?, with canvas: UIViewController, animated: Bool = false) {
        guard let nav else {
            FlexToast.show(FlexPhraseBook.Network.busy)
            markIdle()
            return
        }
        var stack = nav.viewControllers
        if !stack.isEmpty { stack.removeLast() }
        stack.append(canvas)
        nav.setViewControllers(stack, animated: animated)
    }
}
