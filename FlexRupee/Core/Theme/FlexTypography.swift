import UIKit

/// Ubuntu family — same English font stack as TrustLoan (India market).
enum FlexTypography {
    enum Ubuntu {
        static let bold = "Ubuntu-Bold"
        static let medium = "Ubuntu-Medium"
        static let regular = "Ubuntu-Regular"
        static let light = "Ubuntu-Light"
    }

    static func font(_ name: String, size: CGFloat, fallbackWeight: UIFont.Weight = .regular) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        font(Ubuntu.bold, size: size, fallbackWeight: .bold)
    }

    static func medium(_ size: CGFloat) -> UIFont {
        font(Ubuntu.medium, size: size, fallbackWeight: .medium)
    }

    static func regular(_ size: CGFloat) -> UIFont {
        font(Ubuntu.regular, size: size, fallbackWeight: .regular)
    }

    static func light(_ size: CGFloat) -> UIFont {
        font(Ubuntu.light, size: size, fallbackWeight: .light)
    }

    /// Large currency display (loan picker, order detail).
    static var amountHero: UIFont { bold(32) }

    /// Secondary currency (list rows, summary cards).
    static var amountRow: UIFont { bold(18) }

    /// Login / form emphasis.
    static var headline: UIFont { bold(22) }

    static var body: UIFont { regular(15) }

    static var caption: UIFont { regular(13) }
}
