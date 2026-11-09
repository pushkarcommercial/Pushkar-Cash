import UIKit
import SnapKit

/// P44 Location / P51 Camera / P52 Contacts secondary permission dialogs.
enum FlexPermissionSheet {
    enum Kind {
        case location
        case camera
        case contacts

        var art: String {
            switch self {
            case .location: return FlexSliceCatalog.dialogNotifyArt
            case .camera: return FlexSliceCatalog.dialogCameraArt
            case .contacts: return FlexSliceCatalog.dialogContactsArt
            }
        }

        var title: String {
            switch self {
            case .location: return FlexPhraseBook.Consent.locationTitle
            case .camera: return FlexPhraseBook.Capture.cameraTitle
            case .contacts: return FlexPhraseBook.Consent.contactsTitle
            }
        }

        var message: String {
            switch self {
            case .location: return FlexPhraseBook.Consent.locationSettings
            case .camera: return FlexPhraseBook.Capture.cameraBody
            case .contacts: return FlexPhraseBook.Consent.contactsBody
            }
        }
    }

    static func present(on host: UIViewController,
                        kind: Kind,
                        onConfirm: @escaping () -> Void,
                        onCancel: (() -> Void)? = nil) {
        let overlay = FlexPermissionOverlay(frame: host.view.bounds)
        overlay.configure(kind: kind, onConfirm: onConfirm, onCancel: onCancel)
        host.view.addSubview(overlay)
        // Keep the permission guidance above inline content.
        host.view.bringSubviewToFront(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private final class FlexPermissionOverlay: UIView {
    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let cancelButton = UIButton(type: .custom)
    private let confirmButton = UIButton(type: .custom)
    private var onConfirm: (() -> Void)?
    private var onCancel: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.permissionScrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textAlignment = .center
        titleLabel.textColor = FlexPalette.inkPrimary
        bodyLabel.font = FlexTypography.regular(14)
        bodyLabel.textColor = FlexPalette.inkSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        FlexDialogLayout.styleOutlineAction(cancelButton)
        FlexDialogLayout.stylePrimaryAction(confirmButton)
        cancelButton.setTitle(FlexPhraseBook.Dialog.cancel, for: .normal)
        confirmButton.setTitle(FlexPhraseBook.Dialog.confirm, for: .normal)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(kind: FlexPermissionSheet.Kind,
                   onConfirm: @escaping () -> Void,
                   onCancel: (() -> Void)?) {
        iconView.image = FlexSlice.slice(kind.art)
        titleLabel.text = kind.title
        bodyLabel.text = kind.message
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        buildLayoutIfNeeded()
    }

    private func buildLayoutIfNeeded() {
        guard cardView.superview == nil else { return }
        addSubview(cardView)
        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)

        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(buttonRow)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.permissionCardHorizontalInset)
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
            make.size.equalTo(FlexDialogMetrics.permissionIconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(FlexDialogMetrics.iconToTitle)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
        }
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(FlexDialogMetrics.titleToBody)
            make.leading.trailing.equalTo(titleLabel)
        }
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(FlexDialogMetrics.bodyToButtons)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        confirmButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
    }

    @objc private func cancelTapped() {
        removeFromSuperview()
        onCancel?()
    }

    @objc private func confirmTapped() {
        removeFromSuperview()
        onConfirm?()
    }
}
