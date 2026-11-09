import UIKit

/// Design tokens aligned with AI-IN32-DC mockups (P2 Home / P3 Home).
enum FlexTheme {
    static func styleHubApplyButton(_ button: UIButton) {
        button.backgroundColor = FlexPalette.primaryTeal
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(17)
        button.flexRoundCorners(27)
    }

    static func styleCheckInButton(_ button: UIButton) {
        button.backgroundColor = FlexPalette.accentGreen
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(14)
        button.flexRoundCorners(21)
    }

    static func stylePrimaryButton(_ button: UIButton) {
        button.backgroundColor = FlexPalette.primaryTeal
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(16)
        button.flexRoundCorners(24)
    }

    static func styleGateOTPButton(_ button: UIButton) {
        button.backgroundColor = FlexPalette.primaryTeal
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.medium(12)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.75
        button.titleLabel?.textAlignment = .center
        button.flexRoundCorners(10)
        button.contentEdgeInsets = .zero
    }

    static func styleGateInputRow(_ row: UIView) {
        row.backgroundColor = FlexPalette.cardWhite
        row.flexRoundCorners(12)
        row.layer.borderWidth = 1
        row.layer.borderColor = FlexPalette.fieldBorder.cgColor
    }

    static func styleAccentButton(_ button: UIButton) {
        button.backgroundColor = FlexPalette.accentGreen
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(15)
        button.flexRoundCorners(24)
    }

    static func styleCard(_ view: UIView, elevated: Bool = true) {
        view.backgroundColor = FlexPalette.cardWhite
        view.flexRoundCorners(20)
        if elevated {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.06
            view.layer.shadowOffset = CGSize(width: 0, height: 4)
            view.layer.shadowRadius = 12
            view.layer.masksToBounds = false
        }
    }

    static func styleBorderedCard(_ view: UIView) {
        view.backgroundColor = FlexPalette.cardWhite
        view.flexRoundCorners(16)
        view.layer.borderWidth = 1
        view.layer.borderColor = FlexPalette.fieldBorder.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.04
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.masksToBounds = false
    }

    static func styleBanner(_ view: UIView) {
        view.backgroundColor = FlexPalette.bannerGray
        view.flexRoundCorners(14)
    }

    static func makeRatePill(_ text: String) -> UILabel {
        let pill = UILabel()
        pill.text = text
        pill.font = FlexTypography.medium(11)
        pill.textColor = .white
        pill.backgroundColor = FlexPalette.accentGreen
        pill.textAlignment = .center
        pill.flexRoundCorners(12)
        return pill
    }

    static func makeField() -> FlexBoundedField {
        let field = FlexBoundedField()
        field.backgroundColor = .white
        field.flexRoundCorners(12)
        field.layer.borderWidth = 1
        field.layer.borderColor = FlexPalette.fieldBorder.cgColor
        field.font = FlexTypography.regular(15)
        field.textColor = FlexPalette.inkPrimary
        return field
    }
}
