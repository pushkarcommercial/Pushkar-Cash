import UIKit
import SnapKit
import RxSwift
import Kingfisher

final class FlexRecommendApplyCanvas: FlexBaseCanvas, UITableViewDataSource, UITableViewDelegate {
    private let cards: [OfferCardShard]
    private let pilot = FlexRecommendApplyPilot()
    private let disposeBag = DisposeBag()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let dock = UIView()
    private let applyButton = FlexPrimaryButton()
    private let agreementCheck = UIButton(type: .custom)
    private let agreementLabel = UILabel()
    private let termsLink = UIButton(type: .system)

    init(cards: [OfferCardShard]) {
        self.cards = cards
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Hub.selectLoanAmount)
        flexNavBar.onBack = { [weak self] in
            self?.handleBackTapped()
        }
        layoutUI()
        bindPilot()
        pilot.bind(cards: cards)
        // Footer/cells must rebuild after lines are ready (bind is after first footer build).
        tableView.reloadData()
        rebuildFooter()
    }

    private func handleBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func layoutUI() {
        applyButton.setTitle(FlexPhraseBook.Loan.applyNow, for: .normal)
        applyButton.flexRoundCorners(27)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 280
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(FlexRecommendProductCell.self, forCellReuseIdentifier: FlexRecommendProductCell.reuseId)
        tableView.tableFooterView = makeFooter()

        dock.backgroundColor = .white
        dock.layer.shadowColor = UIColor.black.cgColor
        dock.layer.shadowOpacity = 0.06
        dock.layer.shadowOffset = CGSize(width: 0, height: -2)
        dock.layer.shadowRadius = 6
        let hairline = UIView()
        hairline.backgroundColor = FlexPalette.fieldBorder
        let agreement = FlexLoanWidgets.makeAgreementRow(checkbox: agreementCheck,
                                                         label: agreementLabel,
                                                         linkButton: termsLink)
        agreementCheck.addTarget(self, action: #selector(toggleAgreement), for: .touchUpInside)
        termsLink.addTarget(self, action: #selector(openTerms), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(dock)
        dock.addSubview(hairline)
        dock.addSubview(agreement)
        dock.addSubview(applyButton)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(dock.snp.top)
        }
        dock.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        hairline.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        agreement.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        applyButton.snp.makeConstraints { make in
            make.top.equalTo(agreement.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(dock.safeAreaLayoutGuide).offset(-12)
            make.height.equalTo(54)
        }
    }

    private func bindPilot() {
        pilot.reloadSignal.stream.subscribe(onNext: { [weak self] in
            self?.rebuildFooter()
            self?.tableView.reloadData()
        }).disposed(by: disposeBag)
        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)
        pilot.isBusy.stream.subscribe(onNext: { [weak self] busy in
            self?.applyButton.isEnabled = !busy
            self?.applyButton.alpha = busy ? 0.55 : 1
        }).disposed(by: disposeBag)
        pilot.openSuccess.stream.subscribe(onNext: { [weak self] orderIds in
            self?.presentLoanSuccess(orderIds: orderIds)
        }).disposed(by: disposeBag)
        rebuildFooter()
    }

    private func makeFooter() -> UIView {
        let wrap = UIView()
        wrap.backgroundColor = .clear
        let bankBar = UIView()
        bankBar.backgroundColor = FlexPalette.dockBlack
        bankBar.flexRoundCorners(14)
        let bankIcon = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        bankIcon.contentMode = .scaleAspectFit
        let bankMask = UILabel()
        bankMask.font = FlexTypography.medium(14)
        bankMask.textColor = FlexPalette.accentGreen
        bankMask.textAlignment = .right
        bankMask.text = pilot.bankMask()
        bankBar.addSubview(bankIcon)
        bankBar.addSubview(bankMask)
        bankIcon.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview().inset(14)
            make.width.height.equalTo(22)
        }
        bankMask.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview().inset(14)
            make.leading.greaterThanOrEqualTo(bankIcon.snp.trailing).offset(8)
        }
        bankBar.snp.makeConstraints { $0.height.equalTo(52) }

        let totals = pilot.totals()
        let summary = FlexLoanWidgets.makeWhiteCard()
        let summaryStack = UIStackView()
        summaryStack.axis = .vertical
        summaryStack.spacing = 10
        summary.addSubview(summaryStack)
        summaryStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        summaryStack.addArrangedSubview(makeSummaryRow(FlexPhraseBook.Hub.totalAmount,
                                                       RupeeAmountFormat.rupee("\(totals.amount)")))
        summaryStack.addArrangedSubview(makeSummaryRow(FlexPhraseBook.Hub.totalFee,
                                                       RupeeAmountFormat.rupee("\(totals.fee)")))
        summaryStack.addArrangedSubview(makeSummaryRow(FlexPhraseBook.Loan.amountReceived,
                                                       RupeeAmountFormat.rupee("\(totals.received)")))

        let stack = UIStackView(arrangedSubviews: [bankBar, summary])
        stack.axis = .vertical
        stack.spacing = 12
        wrap.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-8)
        }
        wrap.layoutIfNeeded()
        let height = stack.systemLayoutSizeFitting(CGSize(width: view.bounds.width - 32, height: 0),
                                                   withHorizontalFittingPriority: .required,
                                                   verticalFittingPriority: .fittingSizeLevel).height + 16
        wrap.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: max(height, 160))
        return wrap
    }

    private func makeSummaryRow(_ title: String, _ value: String) -> UIView {
        let row = UIView()
        let left = UILabel()
        left.text = title
        left.font = FlexTypography.regular(13)
        left.textColor = FlexPalette.inkSecondary
        let right = UILabel()
        right.text = value
        right.font = FlexTypography.medium(14)
        right.textColor = FlexPalette.inkPrimary
        right.textAlignment = .right
        row.addSubview(left)
        row.addSubview(right)
        left.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        right.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(left.snp.trailing).offset(8)
        }
        return row
    }

    private func rebuildFooter() {
        tableView.tableFooterView = makeFooter()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pilot.lines.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FlexRecommendProductCell.reuseId, for: indexPath)
            as! FlexRecommendProductCell
        let line = pilot.lines.value[indexPath.row]
        cell.bind(line)
        cell.onToggle = { [weak self] in self?.pilot.toggleSelect(at: indexPath.row) }
        cell.onMinus = { [weak self] in self?.pilot.stepAmount(at: indexPath.row, delta: -1) }
        cell.onPlus = { [weak self] in self?.pilot.stepAmount(at: indexPath.row, delta: 1) }
        cell.onTerm = { [weak self] in self?.presentTermPicker(at: indexPath.row) }
        cell.onDetails = { [weak self] in self?.presentLoanDetails(at: indexPath.row) }
        cell.onAmountHint = { [weak self] in self?.presentFieldHint(.amountReceived, scene: .product) }
        return cell
    }

    private func presentLoanDetails(at index: Int) {
        guard pilot.lines.value.indices.contains(index) else { return }
        let line = pilot.lines.value[index]
        guard let term = line.currentTerm else { return }
        FlexLoanDetailsSheet.present(on: self,
                                     title: line.title,
                                     logoURL: line.logoURL,
                                     loanAmount: line.loanAmount,
                                     term: term)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        flexNavBar.setTitleHidden(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { flexNavBar.setTitleHidden(false) }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flexNavBar.setTitleHidden(false)
    }

    private func presentTermPicker(at index: Int) {
        let options = pilot.lines.value[index].termOptions()
        guard options.count > 1 else { return }
        FlexLedgerPickerSheet.present(on: self,
                                      title: FlexPhraseBook.Loan.selectTerm,
                                      options: options,
                                      selectedIndex: pilot.lines.value[index].termIndex) { [weak self] picked in
            self?.pilot.setTerm(at: index, termIndex: picked)
        }
    }

    @objc private func toggleAgreement() {
        agreementCheck.isSelected.toggle()
    }

    @objc private func openTerms() {
        FlexLegalDocLaunch.open(.termsOfLoan, from: self)
    }

    @objc private func applyTapped() {
        pilot.submit(from: self, agreed: agreementCheck.isSelected)
    }

    private func presentLoanSuccess(orderIds: [String]) {
        // Back from success must not return to apply — leaveStyle hubHome.
        let success = FlexLoanSuccessCanvas(orderIds: orderIds, leaveStyle: .hubHome)
        let nav = flexTopMostNav() ?? navigationController
        FlexRecommendLaunch.replaceTop(of: nav, with: success, animated: true)
    }
}

private final class FlexRecommendProductCell: UITableViewCell {
    static let reuseId = "FlexRecommendProductCell"

    var onToggle: (() -> Void)?
    var onMinus: (() -> Void)?
    var onPlus: (() -> Void)?
    var onTerm: (() -> Void)?
    var onDetails: (() -> Void)?
    var onAmountHint: (() -> Void)?

    private let card = FlexLoanWidgets.makeWhiteCard()
    private let logo = UIImageView()
    private let logoMark = UILabel()
    private let nameLabel = UILabel()
    private let check = UIButton(type: .custom)
    private let amountTip = UILabel()
    private let minusButton = UIButton(type: .custom)
    private let plusButton = UIButton(type: .custom)
    private let amountLabel = UILabel()
    private let termRow = UIView()
    private let receivedRow = UIView()
    private let detailsButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        logo.contentMode = .scaleAspectFill
        logo.backgroundColor = FlexPalette.logoTile
        logo.flexRoundCorners(12)
        logo.clipsToBounds = true
        logoMark.text = "LOGO"
        logoMark.font = FlexTypography.bold(9)
        logoMark.textColor = .white
        logoMark.textAlignment = .center
        logo.addSubview(logoMark)
        logoMark.snp.makeConstraints { $0.edges.equalToSuperview() }

        nameLabel.font = FlexTypography.bold(16)
        nameLabel.textColor = FlexPalette.inkPrimary
        check.setImage(FlexSlice.slice(FlexSliceCatalog.agreeMossIdle), for: .normal)
        check.setImage(FlexSlice.slice(FlexSliceCatalog.agreeSageMarked), for: .selected)
        check.addTarget(self, action: #selector(toggle), for: .touchUpInside)

        amountTip.font = FlexTypography.regular(12)
        amountTip.textColor = FlexPalette.inkTertiary
        amountTip.textAlignment = .center

        [minusButton, plusButton].forEach { button in
            button.titleLabel?.font = FlexTypography.bold(22)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = FlexPalette.primaryTeal
            button.flexRoundCorners(12)
        }
        minusButton.setTitle("−", for: .normal)
        plusButton.setTitle("+", for: .normal)
        minusButton.addTarget(self, action: #selector(minus), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plus), for: .touchUpInside)

        amountLabel.font = FlexTypography.bold(32)
        amountLabel.textAlignment = .center
        amountLabel.textColor = FlexPalette.inkPrimary

        detailsButton.setTitle(FlexPhraseBook.Hub.loanDetailsExpand, for: .normal)
        detailsButton.setTitleColor(FlexPalette.inkTertiary, for: .normal)
        detailsButton.titleLabel?.font = FlexTypography.regular(13)
        detailsButton.addTarget(self, action: #selector(details), for: .touchUpInside)

        contentView.addSubview(card)
        card.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-6)
        }

        let header = UIView()
        header.addSubview(logo)
        header.addSubview(nameLabel)
        header.addSubview(check)
        logo.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.height.equalTo(40)
        }
        check.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(logo.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(check.snp.leading).offset(-8)
        }

        let stepper = UIView()
        stepper.addSubview(minusButton)
        stepper.addSubview(amountLabel)
        stepper.addSubview(plusButton)
        minusButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        plusButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        amountLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(minusButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(plusButton.snp.leading).offset(-8)
        }
        stepper.snp.makeConstraints { $0.height.equalTo(48) }

        let stack = UIStackView(arrangedSubviews: [header, amountTip, stepper, termRow, receivedRow, detailsButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(16, after: header)
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
    }

    func bind(_ line: FlexRecommendLine) {
        nameLabel.text = line.title
        check.isSelected = line.isSelected
        if let raw = line.logoURL, let url = URL(string: raw), !raw.isEmpty {
            logoMark.isHidden = true
            logo.kf.setImage(with: url, placeholder: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        } else {
            logo.image = nil
            logoMark.isHidden = false
        }
        amountTip.text = line.isSelected && line.canStepAmount
            ? FlexPhraseBook.Hub.selectAmountManually
            : FlexPhraseBook.Hub.loanAmountRupee
        minusButton.isHidden = !line.canStepAmount
        plusButton.isHidden = !line.canStepAmount
        minusButton.alpha = line.amountIndex > 0 ? 1 : 0.45
        plusButton.alpha = line.amountIndex < max(0, line.tiers.count - 1) ? 1 : 0.45
        amountLabel.text = RupeeAmountFormat.indian(line.loanAmount)
        amountLabel.textColor = line.canStepAmount ? FlexPalette.inkPrimary : FlexPalette.inkPrimary
        let multiTerm = (line.currentTier?.termRows.count ?? 0) > 1
        fillMetricRow(termRow,
                      title: multiTerm ? FlexPhraseBook.Loan.selectTerm : FlexPhraseBook.Loan.loanTerm,
                      value: line.termOptions().indices.contains(line.termIndex)
                        ? line.termOptions()[line.termIndex]
                        : "\(line.currentTerm?.showTerm ?? line.currentTerm?.loanTerm ?? 0) Days",
                      chevron: multiTerm,
                      hint: false)
        fillMetricRow(receivedRow,
                      title: FlexPhraseBook.Loan.amountReceived,
                      value: RupeeAmountFormat.indian(line.receivedAmount),
                      chevron: false,
                      hint: true)
    }

    private func fillMetricRow(_ row: UIView, title: String, value: String, chevron: Bool, hint: Bool) {
        row.subviews.forEach { $0.removeFromSuperview() }
        let left = UILabel()
        left.text = title
        left.font = FlexTypography.regular(13)
        left.textColor = FlexPalette.inkSecondary
        let right = UILabel()
        right.text = value
        right.font = FlexTypography.medium(14)
        right.textColor = FlexPalette.inkPrimary
        right.textAlignment = .right
        row.addSubview(left)
        row.addSubview(right)
        if hint {
            let spark = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanInfoSpark))
            spark.contentMode = .scaleAspectFit
            spark.isUserInteractionEnabled = true
            spark.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hintTap)))
            row.addSubview(spark)
            spark.snp.makeConstraints { make in
                make.leading.equalTo(left.snp.trailing).offset(4)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(14)
            }
        }
        left.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        if chevron {
            let arrow = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow)?.withRenderingMode(.alwaysOriginal))
            arrow.contentMode = .scaleAspectFit
            row.addSubview(arrow)
            arrow.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.width.height.equalTo(12)
            }
            right.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalTo(arrow.snp.leading).offset(-4)
            }
            row.isUserInteractionEnabled = true
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(termTap)))
        } else {
            right.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
            }
        }
            row.snp.remakeConstraints { $0.height.greaterThanOrEqualTo(22) }
    }

    @objc private func toggle() { onToggle?() }
    @objc private func minus() { onMinus?() }
    @objc private func plus() { onPlus?() }
    @objc private func termTap() { onTerm?() }
    @objc private func details() { onDetails?() }
    @objc private func hintTap() { onAmountHint?() }
}
