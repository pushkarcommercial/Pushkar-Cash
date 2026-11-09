import UIKit
import SnapKit

/// KYC ID / tax photo unclear — codes `6212011` / `6212201` only.
/// Layout matches P53 Upload Error (white card, vertical tip rows, Upload again).
enum FlexUploadErrorSheet {
    static func present(on host: UIViewController, onConfirm: @escaping () -> Void) {
        let overlay = FlexUploadErrorOverlay(frame: host.view.bounds)
        overlay.onConfirm = onConfirm
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private final class FlexUploadErrorOverlay: UIView {
    var onConfirm: (() -> Void)?

    private enum Layout {
        static let tipFailInk = UIColor(hex: 0xF2A0A0)
        static let tipOkInk = UIColor(hex: 0x8CCF91)
        static let cardWidth: CGFloat = 300
        static let tipArtWidth: CGFloat = 72
        static let tipArtHeight: CGFloat = 48
    }

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let tipsStack = UIStackView()
    private let confirmButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.scrim
        isUserInteractionEnabled = true

        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        cardView.clipsToBounds = true

        titleLabel.text = "\(FlexPhraseBook.Verify.uploadErrorTitle) \(FlexPhraseBook.Verify.uploadErrorBody)"
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.font = FlexTypography.bold(16)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        tipsStack.axis = .vertical
        tipsStack.spacing = 16
        tipsStack.alignment = .fill
        tipsStack.addArrangedSubview(makeTipRow(
            art: FlexSliceCatalog.dialogErrorStepOne,
            text: FlexPhraseBook.Verify.uploadErrorTipSmall,
            ink: Layout.tipFailInk
        ))
        tipsStack.addArrangedSubview(makeTipRow(
            art: FlexSliceCatalog.dialogErrorStepTwo,
            text: FlexPhraseBook.Verify.uploadErrorTipCovered,
            ink: Layout.tipFailInk
        ))
        tipsStack.addArrangedSubview(makeTipRow(
            art: FlexSliceCatalog.dialogErrorStepThree,
            text: FlexPhraseBook.Verify.uploadErrorTipClear,
            ink: Layout.tipOkInk
        ))

        confirmButton.setTitle(FlexPhraseBook.Verify.uploadAgain, for: .normal)
        FlexDialogLayout.stylePrimaryAction(confirmButton)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(tipsStack)
        cardView.addSubview(confirmButton)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(Layout.cardWidth)
            make.leading.greaterThanOrEqualToSuperview().offset(FlexDialogMetrics.cardHorizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-FlexDialogMetrics.cardHorizontalInset)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        tipsStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(28)
        }
        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(tipsStack.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(FlexDialogMetrics.buttonHeight)
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeTipRow(art: String, text: String, ink: UIColor) -> UIView {
        let row = UIView()

        let imageView = UIImageView(image: FlexSlice.slice(art)?.withRenderingMode(.alwaysOriginal))
        imageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(13)
        label.textColor = ink
        label.numberOfLines = 0

        row.addSubview(imageView)
        row.addSubview(label)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(Layout.tipArtWidth)
            make.height.equalTo(Layout.tipArtHeight)
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(imageView)
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        return row
    }

    @objc private func confirmTapped() {
        removeFromSuperview()
        onConfirm?()
    }
}
