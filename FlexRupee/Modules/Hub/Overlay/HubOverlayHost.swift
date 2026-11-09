import UIKit
import SnapKit

/// Owns the pending-withdrawal overlay on the home screen.
final class HubOverlayHost {
    private weak var hostView: UIView?
    private var withdrawPanel: HubWithdrawPanel?

    func install(on view: UIView) {
        hostView = view
    }

    func showWithdraw(dealId: String?, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        guard let hostView else { return }
        if withdrawPanel != nil { return }
        let panel = HubWithdrawPanel()
        panel.onConfirm = onConfirm
        panel.onDismiss = onDismiss
        withdrawPanel = panel
        hostView.addSubview(panel)
        panel.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func dismissWithdraw() {
        withdrawPanel?.removeFromSuperview()
        withdrawPanel = nil
    }

}

/// Pencil withdraw popup — icon above card, single Withdraw CTA below.
private final class HubWithdrawPanel: UIView {
    var onConfirm: (() -> Void)?
    var onDismiss: (() -> Void)?

    private enum Layout {
        static let cardWidth: CGFloat = 295
        static let cardHeight: CGFloat = 136
        static let cardCorner: CGFloat = 12
        static let iconSize: CGFloat = 66
        static let iconToCard: CGFloat = 18
        static let buttonTop: CGFloat = 26
        static let buttonWidth: CGFloat = 255
        static let buttonHeight: CGFloat = 60
        static let closeSize: CGFloat = 28
    }

    private let iconView = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.dialogWithdrawArt))
    private let cardView = UIView()
    private let messageLabel = UILabel()
    private let closeButton = FlexDialogLayout.makeCloseButton()
    private lazy var withdrawButton = FlexDialogLayout.makeTranslucentActionButton(title: FlexPhraseBook.Hub.withdrawGo)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogLayout.inlineScrim
        iconView.contentMode = .scaleAspectFit
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = Layout.cardCorner
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = FlexDialogLayout.cardStroke.cgColor
        messageLabel.text = FlexPhraseBook.Hub.withdrawBody
        messageLabel.font = FlexTypography.regular(14)
        messageLabel.textColor = FlexDialogLayout.bodyInk
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        withdrawButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        layoutUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layoutUI() {
        let stack = UIStackView(arrangedSubviews: [iconView, cardView, withdrawButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Layout.iconToCard
        stack.setCustomSpacing(Layout.buttonTop, after: cardView)
        addSubview(stack)
        addSubview(closeButton)
        cardView.addSubview(messageLabel)
        FlexDialogLayout.pinContentCentered(stack, in: self)
        iconView.snp.makeConstraints { $0.size.equalTo(Layout.iconSize) }
        cardView.snp.makeConstraints { make in
            make.width.equalTo(Layout.cardWidth)
            make.height.equalTo(Layout.cardHeight)
        }
        withdrawButton.snp.makeConstraints { make in
            make.width.equalTo(Layout.buttonWidth)
            make.height.equalTo(Layout.buttonHeight)
        }
        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(22)
        }
        closeButton.snp.makeConstraints { make in
            make.bottom.equalTo(cardView.snp.top).offset(-10)
            make.trailing.equalTo(cardView.snp.trailing)
            make.width.height.equalTo(Layout.closeSize)
        }
    }

    @objc private func cancelTapped() {
        onDismiss?()
        removeFromSuperview()
    }

    @objc private func confirmTapped() {
        onConfirm?()
    }
}
