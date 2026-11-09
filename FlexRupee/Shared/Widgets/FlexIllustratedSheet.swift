import UIKit
import SnapKit

enum FlexIllustratedSheet {
    static func present(on host: UIViewController,
                        art: String,
                        title: String? = nil,
                        message: String,
                        confirmTitle: String = FlexPhraseBook.Dialog.confirm,
                        cancelTitle: String = FlexPhraseBook.Dialog.cancel,
                        showsCancel: Bool = true,
                        buttonOrder: FlexDialogButtonOrder = .cancelThenConfirm,
                        bodyAlignment: NSTextAlignment = .center,
                        onConfirm: @escaping () -> Void,
                        onCancel: (() -> Void)? = nil) {
        let overlay = FlexIllustratedOverlay(frame: host.view.bounds)
        overlay.configure(art: art, title: title, message: message,
                          confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                          showsCancel: showsCancel, buttonOrder: buttonOrder,
                          bodyAlignment: bodyAlignment,
                          onConfirm: onConfirm, onCancel: onCancel)
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

/// P39–P52 card dialog — icon, title, body, and CTAs inside one white card.
private final class FlexIllustratedOverlay: UIView {
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
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textAlignment = .center
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.isHidden = true
        bodyLabel.font = FlexTypography.regular(14)
        bodyLabel.textColor = FlexPalette.inkSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        FlexDialogLayout.styleOutlineAction(cancelButton)
        FlexDialogLayout.stylePrimaryAction(confirmButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(art: String, title: String?, message: String,
                   confirmTitle: String, cancelTitle: String,
                   showsCancel: Bool, buttonOrder: FlexDialogButtonOrder,
                   bodyAlignment: NSTextAlignment,
                   onConfirm: @escaping () -> Void, onCancel: (() -> Void)?) {
        iconView.image = FlexSlice.slice(art)
        if let title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.isHidden = false
        }
        bodyLabel.text = message
        bodyLabel.textAlignment = bodyAlignment
        cancelButton.setTitle(cancelTitle, for: .normal)
        confirmButton.setTitle(confirmTitle, for: .normal)
        cancelButton.isHidden = !showsCancel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        buildLayout(showsCancel: showsCancel, buttonOrder: buttonOrder)
    }

    private func buildLayout(showsCancel: Bool, buttonOrder: FlexDialogButtonOrder) {
        guard cardView.superview == nil else { return }
        addSubview(cardView)
        cardView.addSubview(iconView)
        if !titleLabel.isHidden { cardView.addSubview(titleLabel) }
        cardView.addSubview(bodyLabel)

        let orderedButtons: [UIButton] = {
            switch buttonOrder {
            case .cancelThenConfirm:
                return showsCancel ? [cancelButton, confirmButton] : [confirmButton]
            case .confirmThenCancel:
                return showsCancel ? [confirmButton, cancelButton] : [confirmButton]
            }
        }()
        let buttonRow = UIStackView(arrangedSubviews: orderedButtons)
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(buttonRow)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardHorizontalInset)
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
            make.size.equalTo(FlexDialogMetrics.iconSize)
        }
        if titleLabel.isHidden {
            bodyLabel.snp.makeConstraints { make in
                make.top.equalTo(iconView.snp.bottom).offset(FlexDialogMetrics.iconToTitle)
                make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            }
        } else {
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(iconView.snp.bottom).offset(FlexDialogMetrics.iconToTitle)
                make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            }
            bodyLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(FlexDialogMetrics.titleToBody)
                make.leading.trailing.equalTo(titleLabel)
            }
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
