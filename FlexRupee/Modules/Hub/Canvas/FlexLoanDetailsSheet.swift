import UIKit
import SnapKit
import Kingfisher

/// Product-apply “Loan details >>” popup — EMI vs non-EMI layouts per AI-IN32-DC Success Dialog.
enum FlexLoanDetailsSheet {
    static func present(on host: UIViewController,
                        title: String,
                        logoURL: String?,
                        loanAmount: String,
                        term: OfferTermRowShard) {
        let overlay = FlexLoanDetailsOverlay(frame: host.view.bounds)
        overlay.configure(title: title, logoURL: logoURL, loanAmount: loanAmount, term: term,
                          onHint: { kind in
                              FlexToast.show(FlexPhraseBook.FieldHint.message(for: kind, scene: .product),
                                             on: overlay)
                          })
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private final class FlexLoanDetailsOverlay: UIView {
    private let cardView = UIView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let confirmButton = UIButton(type: .custom)
    private var onHint: ((FlexFieldHintKind) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        contentStack.axis = .vertical
        contentStack.spacing = 12
        confirmButton.setTitle(FlexPhraseBook.Dialog.confirm, for: .normal)
        FlexDialogLayout.stylePrimaryAction(confirmButton)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String,
                   logoURL: String?,
                   loanAmount: String,
                   term: OfferTermRowShard,
                   onHint: @escaping (FlexFieldHintKind) -> Void) {
        self.onHint = onHint
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        contentStack.addArrangedSubview(makeHeader(title: title, logoURL: logoURL, loanAmount: loanAmount))
        buildRows(from: term).forEach { contentStack.addArrangedSubview($0) }
        installLayoutIfNeeded()
    }

    private func installLayoutIfNeeded() {
        guard cardView.superview == nil else { return }
        addSubview(cardView)
        cardView.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        cardView.addSubview(confirmButton)
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.permissionCardHorizontalInset)
            // Cap tall content; actual height comes from scrollView ↔ contentStack hug below.
            make.height.lessThanOrEqualToSuperview().multipliedBy(0.82)
        }
        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
            make.height.equalTo(FlexDialogMetrics.buttonHeight)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(confirmButton.snp.top).offset(-FlexDialogMetrics.bodyToButtons)
            // Without this, Auto Layout collapses scrollView to 0 and rows never appear.
            make.height.equalTo(contentStack).priority(.high)
        }
        contentStack.snp.makeConstraints { make in
            make.top.bottom.equalTo(scrollView.contentLayoutGuide)
            make.leading.trailing.equalTo(scrollView.frameLayoutGuide)
                .inset(FlexDialogMetrics.cardPadding)
        }
    }

    private func makeHeader(title: String, logoURL: String?, loanAmount: String) -> UIView {
        let row = UIView()
        let logo = UIImageView()
        logo.contentMode = .scaleAspectFill
        logo.backgroundColor = FlexPalette.logoTile
        logo.flexRoundCorners(8)
        logo.clipsToBounds = true
        let mark = UILabel()
        mark.text = "LOGO"
        mark.font = FlexTypography.bold(9)
        mark.textColor = .white
        mark.textAlignment = .center
        logo.addSubview(mark)
        mark.snp.makeConstraints { $0.edges.equalToSuperview() }
        if let logoURL, let url = URL(string: logoURL), !logoURL.isEmpty {
            mark.isHidden = true
            logo.kf.setImage(with: url, placeholder: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        }

        let name = UILabel()
        name.text = title
        name.font = FlexTypography.bold(16)
        name.textColor = FlexPalette.inkPrimary

        let amount = UILabel()
        amount.text = RupeeAmountFormat.rupee(loanAmount)
        amount.font = FlexTypography.bold(16)
        amount.textColor = FlexPalette.inkPrimary
        amount.textAlignment = .right

        row.addSubview(logo)
        row.addSubview(name)
        row.addSubview(amount)
        logo.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.height.equalTo(40)
        }
        amount.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        name.snp.makeConstraints { make in
            make.leading.equalTo(logo.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(amount.snp.leading).offset(-8)
        }
        return row
    }

    /// Aligns with FlexLoanCanvas / LedgerDetail EMI gating; field order matches Success Dialog mockups.
    private func buildRows(from term: OfferTermRowShard) -> [UIView] {
        var models: [FlexLoanFieldRowModel] = []
        let days = term.showTerm ?? term.loanTerm ?? 0
        if term.hasEMI {
            models.append(.init(label: FlexPhraseBook.Loan.loanTerm,
                                value: "\(days) (Days)",
                                hintKind: nil,
                                selectable: false))
        } else {
            models.append(.init(label: FlexPhraseBook.Loan.loanPeriod,
                                value: "\(days) Days",
                                hintKind: nil,
                                selectable: false))
        }

        appendMoney(&models, FlexPhraseBook.Loan.amountReceived,
                    term.arrivalAmount ?? term.receiptAmount, hint: .amountReceived)
        appendMoney(&models, FlexPhraseBook.Loan.serviceFee, term.feeAmount, hint: .serviceFee)
        if term.interestAmount != "0", !(term.interestAmount ?? "").isEmpty {
            appendMoney(&models, FlexPhraseBook.Loan.interest, term.interestAmount, hint: .interest)
        }
        appendMoney(&models, FlexPhraseBook.Loan.gst, term.taxAmount, hint: nil)

        if let apply = term.applyStamp, !apply.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.applyDate, value: apply, hintKind: nil, selectable: false))
        }
        if let due = term.dueStamp, !due.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.dueDate, value: due, hintKind: nil, selectable: false))
        }

        if term.hasEMI {
            if let stamp = term.emiRepayStamp, !stamp.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiDate, value: stamp, hintKind: nil, selectable: false))
            }
            if let amount = term.emiAmount, !amount.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiAmount,
                                    value: RupeeAmountFormat.rupee(amount),
                                    hintKind: nil,
                                    selectable: false))
            }
            let emis = term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !emis.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emis,
                                    value: RupeeAmountFormat.indian(emis),
                                    hintKind: nil,
                                    selectable: false))
            }
        }

        return models.map { model in
            FlexLoanWidgets.makeFieldRow(model, onHint: { [weak self] kind in
                self?.onHint?(kind)
            })
        }
    }

    private func appendMoney(_ rows: inout [FlexLoanFieldRowModel],
                             _ label: String,
                             _ raw: String?,
                             hint: FlexFieldHintKind?) {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        rows.append(.init(label: label, value: RupeeAmountFormat.rupee(raw), hintKind: hint, selectable: false))
    }

    @objc private func confirmTapped() {
        removeFromSuperview()
    }
}
