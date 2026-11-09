import UIKit
import SnapKit

enum CofferConfigBridge {
    static var supportEmail: String {
        let cached = CofferVault.shared.cachedSupportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.isEmpty ? "service@example.com" : cached
    }

    static var siteURL: String {
        let cached = CofferVault.shared.cachedSiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.isEmpty ? "https://www.example.com" : cached
    }
}

enum FlexCofferWidgets {
    private static let cardRadius: CGFloat = 20
    private static let rowInset: CGFloat = 16

    static func makeHintBanner(_ text: String) -> UIView {
        let wrap = UIView()
        wrap.backgroundColor = FlexPalette.bannerGray
        wrap.flexRoundCorners(cardRadius)
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(14)
        label.textColor = FlexPalette.inkSecondary
        label.numberOfLines = 0
        wrap.addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview().inset(rowInset) }
        return wrap
    }

    static func makeWhiteCard() -> UIView {
        let card = UIView()
        card.backgroundColor = FlexPalette.cardWhite
        card.flexRoundCorners(cardRadius)
        return card
    }

    static func makeCopyRow(icon: String, text: String) -> UIView {
        let row = makeWhiteCard()
        let iconView = UIImageView(image: FlexSlice.slice(icon))
        iconView.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(14)
        label.textColor = FlexPalette.inkPrimary
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        let copyBtn = makeCopyButton()
        copyBtn.addAction(UIAction { _ in
            UIPasteboard.general.string = text
            FlexToast.show(FlexPhraseBook.Coffer.copied)
        }, for: .touchUpInside)
        row.addSubview(iconView)
        row.addSubview(label)
        row.addSubview(copyBtn)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(rowInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(copyBtn.snp.leading).offset(-10)
        }
        copyBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-rowInset)
            make.centerY.equalToSuperview()
            make.width.equalTo(72)
            make.height.equalTo(30)
        }
        row.snp.makeConstraints { $0.height.greaterThanOrEqualTo(60) }
        return row
    }

    static func makeCopyButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(
            FlexSlice.slice(FlexSliceCatalog.clipboardTwine)?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        button.adjustsImageWhenHighlighted = false
        button.accessibilityLabel = FlexPhraseBook.Coffer.copy
        return button
    }

    static func makeTextCard(_ text: String) -> UIView {
        let card = makeWhiteCard()
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(14)
        label.textColor = FlexPalette.inkSecondary
        label.numberOfLines = 0
        card.addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview().inset(rowInset) }
        return card
    }

    static func makeFieldCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(14)
        label.textColor = FlexPalette.inkSecondary
        return label
    }

    static func embedScrollStack(on host: UIView, below top: ConstraintItem, stack: UIStackView) {
        stack.spacing = 16
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        host.addSubview(scroll)
        scroll.addSubview(stack)
        scroll.snp.makeConstraints { make in
            make.top.equalTo(top).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16))
            make.width.equalTo(scroll).offset(-32)
        }
    }

    /// Bank-card display — strip spaces (no 4-digit grouping; no space before digits).
    static func groupedAccountNumber(_ raw: String) -> String {
        raw.replacingOccurrences(of: " ", with: "")
    }
}

enum FlexCardConfirmSheet {
    static func present(on host: UIViewController,
                        art: String,
                        title: String,
                        message: String,
                        confirmTitle: String = FlexPhraseBook.Dialog.confirm,
                        cancelTitle: String = FlexPhraseBook.Dialog.cancel,
                        onConfirm: @escaping () -> Void,
                        onCancel: (() -> Void)? = nil) {
        let overlay = FlexCardConfirmOverlay(frame: host.view.bounds)
        overlay.configure(art: art, title: title, message: message,
                          confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                          onConfirm: onConfirm, onCancel: onCancel)
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private final class FlexCardConfirmOverlay: UIView {
    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let confirmButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .custom)
    private var onConfirm: (() -> Void)?
    private var onCancel: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        bodyLabel.font = FlexTypography.regular(14)
        bodyLabel.textColor = FlexPalette.inkSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(art: String, title: String, message: String,
                   confirmTitle: String, cancelTitle: String,
                   onConfirm: @escaping () -> Void, onCancel: (() -> Void)?) {
        iconView.image = FlexSlice.slice(art)
        titleLabel.text = title
        bodyLabel.text = message
        confirmButton.setTitle(confirmTitle, for: .normal)
        cancelButton.setTitle(cancelTitle, for: .normal)
        styleConfirmButton(confirmButton)
        styleCancelButton(cancelButton)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        buildLayout()
    }

    private func buildLayout() {
        guard cardView.superview == nil else { return }
        let buttonRow = UIStackView(arrangedSubviews: [confirmButton, cancelButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(buttonRow)
        addSubview(cardView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
            make.size.equalTo(FlexDialogMetrics.iconSize)
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
        confirmButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        cancelButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardHorizontalInset)
        }
    }

    private func styleConfirmButton(_ button: UIButton) {
        FlexDialogLayout.styleOutlineAction(button)
    }

    private func styleCancelButton(_ button: UIButton) {
        FlexDialogLayout.stylePrimaryAction(button)
    }

    @objc private func confirmTapped() {
        removeFromSuperview()
        onConfirm?()
    }

    @objc private func cancelTapped() {
        removeFromSuperview()
        onCancel?()
    }
}
