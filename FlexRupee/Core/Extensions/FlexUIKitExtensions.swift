import UIKit

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension UIView {
    func flexRoundCorners(_ radius: CGFloat = 16) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
}

extension String {
    var flexDigitsOnly: String {
        filter { $0.isNumber }
    }
}

extension UIViewController {
    func flexTopMostNav() -> UINavigationController? {
        if let nav = navigationController { return nav }
        return presentingViewController?.flexTopMostNav()
    }
}
