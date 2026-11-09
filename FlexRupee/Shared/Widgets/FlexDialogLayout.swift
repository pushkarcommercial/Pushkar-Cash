import UIKit
import SnapKit

/// Shared metrics for AI-IN32-DC card dialogs (P37–P52).
enum FlexDialogMetrics {
    static let scrim = UIColor.black.withAlphaComponent(0.8)
    /// P44 / P51 / P52 permission secondary dialogs — black 80% scrim; card stays white.
    static let permissionScrim = UIColor.black.withAlphaComponent(0.8)
    static let cardHorizontalInset: CGFloat = 42
    /// Permission dialogs use a wider card (P44/P51/P52).
    static let permissionCardHorizontalInset: CGFloat = 28
    static let cardCorner: CGFloat = 32
    static let cardPadding: CGFloat = 32
    static let iconSize: CGFloat = 64
    /// Full green-circle art from AI-IN32-DC (`wyglsst_tk_*` @3x = 192px).
    static let permissionIconSize: CGFloat = 64
    static let iconToTitle: CGFloat = 20
    static let titleToBody: CGFloat = 10
    static let bodyToButtons: CGFloat = 28
    static let buttonHeight: CGFloat = 48
    static let buttonCorner: CGFloat = 12
    static let buttonSpacing: CGFloat = 12
}

/// Popup metrics aligned with AI-IN32-DC / TrustLoan Pencil popups.
enum FlexDialogLayout {
    static let inlineScrim = FlexDialogMetrics.scrim
    static let upgradeScrim = FlexDialogMetrics.scrim
    static let cardStroke = UIColor(hex: 0xD2D2D2)
    static let permissionStroke = UIColor(hex: 0xB8B8B8)
    static let bodyInk = UIColor(hex: 0x4A4A4A)

    static func pinContentCentered(_ content: UIView, in host: UIView) {
        host.addSubview(content)
        content.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
    }

    static func makeBorderedActionButton(title: String, fill: UIColor) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(16)
        button.backgroundColor = fill
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 0
        button.isExclusiveTouch = true
        return button
    }

    static func makeTranslucentActionButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(16)
        button.backgroundColor = UIColor(white: 1, alpha: 0.28)
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 0
        button.isExclusiveTouch = true
        return button
    }

    static func makeGrayActionButton(title: String, gray: CGFloat = 0.55) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(16)
        button.backgroundColor = UIColor(white: gray, alpha: 1)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 0
        button.isExclusiveTouch = true
        return button
    }

    static func makeCloseButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(FlexSlice.slice(FlexSliceCatalog.dialogCloseMark), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.isExclusiveTouch = true
        return button
    }

    static func styleOutlineAction(_ button: UIButton) {
        button.backgroundColor = .white
        button.flexRoundCorners(FlexDialogMetrics.buttonCorner)
        button.layer.borderWidth = 1
        button.layer.borderColor = FlexPalette.fieldBorder.cgColor
        button.setTitleColor(FlexPalette.inkPrimary, for: .normal)
        button.titleLabel?.font = FlexTypography.medium(15)
        button.isExclusiveTouch = true
    }

    static func stylePrimaryAction(_ button: UIButton) {
        button.backgroundColor = FlexPalette.primaryTeal
        button.flexRoundCorners(FlexDialogMetrics.buttonCorner)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(15)
        button.isExclusiveTouch = true
    }
}

enum FlexDialogButtonOrder {
    case cancelThenConfirm
    case confirmThenCancel
}
