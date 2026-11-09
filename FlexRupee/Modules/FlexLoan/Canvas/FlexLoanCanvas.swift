import UIKit
import SnapKit
import RxSwift

final class FlexLoanCanvas: FlexBaseCanvas, UIScrollViewDelegate {
    private var productId: String
    private let recommendCards: [OfferCardShard]
    private var selectedRecommendIndex = 0
    private let pilot = FlexLoanPilot()
    private let cofferStore = CofferProfileStore.shared
    private let disposeBag = DisposeBag()

    private let pickerStack = UIStackView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let amountTipLabel = UILabel()
    private let amountLabel = UILabel()
    private let minusButton = UIButton(type: .custom)
    private let plusButton = UIButton(type: .custom)
    private let amountHost = UIView()
    private let detailStack = UIStackView()
    private let productRowHost = UIView()
    private let bankMaskLabel = UILabel()
    private let agreementCheck = UIButton(type: .custom)
    private let agreementLabel = UILabel()
    private let termsLink = UIButton(type: .system)
    private let applyButton = FlexPrimaryButton()

    init(productId: String, recommendCards: [OfferCardShard] = []) {
        self.productId = productId
        self.recommendCards = recommendCards
        super.init(nibName: nil, bundle: nil)
    }

    var loanProductId: String { productId }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Loan.title)
        flexNavBar.onBack = { [weak self] in self?.handleBackTapped() }
        layoutUI()
        bindPilot()
        loadBankMask()
        if !recommendCards.isEmpty {
            scrollView.delegate = self
            rebuildRecommendPicker()
        }
        pilot.load(productId: productId)
    }

    private func layoutUI() {
        scrollView.showsVerticalScrollIndicator = false
        contentStack.axis = .vertical
        contentStack.spacing = 12

        detailStack.axis = .vertical
        detailStack.spacing = 8

        applyButton.setTitle(FlexPhraseBook.Loan.applyNow, for: .normal)
        applyButton.flexRoundCorners(27)
        applyButton.snp.makeConstraints { $0.height.equalTo(54) }

        amountTipLabel.font = FlexTypography.regular(12)
        amountTipLabel.textColor = FlexPalette.inkTertiary
        amountTipLabel.textAlignment = .center

        amountLabel.font = FlexTypography.bold(32)
        amountLabel.textAlignment = .center
        [minusButton, plusButton].forEach { button in
            button.titleLabel?.font = FlexTypography.bold(24)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = FlexPalette.primaryTeal
            button.flexRoundCorners(12)
            button.isHidden = true
        }
        minusButton.setTitle("−", for: .normal)
        plusButton.setTitle("+", for: .normal)
        amountHost.addSubview(minusButton)
        amountHost.addSubview(amountLabel)
        amountHost.addSubview(plusButton)
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
            make.leading.greaterThanOrEqualTo(minusButton.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(plusButton.snp.leading).offset(-12)
        }
        amountHost.snp.makeConstraints { $0.height.equalTo(48) }

        let productAmountCard = FlexLoanWidgets.makeWhiteCard()
        productAmountCard.addSubview(productRowHost)
        productAmountCard.addSubview(amountTipLabel)
        productAmountCard.addSubview(amountHost)
        productRowHost.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }
        amountTipLabel.snp.makeConstraints { make in
            make.top.equalTo(productRowHost.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        amountHost.snp.makeConstraints { make in
            make.top.equalTo(amountTipLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }

        let bankBar = UIView()
        bankBar.backgroundColor = FlexPalette.dockBlack
        bankBar.flexRoundCorners(14)
        let bankIcon = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        bankIcon.contentMode = .scaleAspectFit
        bankMaskLabel.font = FlexTypography.medium(14)
        bankMaskLabel.textColor = FlexPalette.accentGreen
        bankMaskLabel.textAlignment = .right
        bankMaskLabel.text = "****************"
        bankBar.addSubview(bankIcon)
        bankBar.addSubview(bankMaskLabel)
        bankIcon.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview().inset(14)
            make.width.height.equalTo(22)
        }
        bankMaskLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview().inset(14)
            make.leading.greaterThanOrEqualTo(bankIcon.snp.trailing).offset(8)
        }
        bankBar.snp.makeConstraints { $0.height.equalTo(52) }

        let detailCard = FlexLoanWidgets.makeWhiteCard()
        detailCard.addSubview(detailStack)
        detailStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        let agreementRow = FlexLoanWidgets.makeAgreementRow(checkbox: agreementCheck,
                                                            label: agreementLabel,
                                                            linkButton: termsLink)
        agreementCheck.addTarget(self, action: #selector(toggleAgreement), for: .touchUpInside)
        termsLink.addTarget(self, action: #selector(openTerms), for: .touchUpInside)

        pickerStack.axis = .vertical
        pickerStack.spacing = 10
        pickerStack.isHidden = recommendCards.isEmpty

        contentStack.addArrangedSubview(pickerStack)
        contentStack.addArrangedSubview(FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Loan.creditBanner))
        contentStack.addArrangedSubview(productAmountCard)
        contentStack.addArrangedSubview(bankBar)
        contentStack.addArrangedSubview(detailCard)
        contentStack.addArrangedSubview(agreementRow)

        view.addSubview(scrollView)
        view.addSubview(applyButton)
        scrollView.addSubview(contentStack)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(applyButton.snp.top).offset(-12)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16,
                                                             bottom: 16, right: 16))
            make.width.equalTo(scrollView).offset(-16 * 2)
        }
        applyButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(54)
        }

        minusButton.addTarget(self, action: #selector(decrease), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(increase), for: .touchUpInside)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    private func updateProductHeader(_ bundle: OfferTermBundleShard?) {
        productRowHost.subviews.forEach { $0.removeFromSuperview() }
        let row = FlexLoanWidgets.makeProductRow(name: bundle?.productTitle ?? "",
                                                 logoURL: bundle?.logoURL)
        productRowHost.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func refreshAmountSection() {
        let multi = pilot.hasMultipleAmountTiers
        amountTipLabel.text = multi ? FlexPhraseBook.Loan.amountTip : FlexPhraseBook.Loan.loanAmountLabel
        minusButton.isHidden = !pilot.canDecreaseAmount
        plusButton.isHidden = !pilot.canIncreaseAmount
        amountLabel.textColor = multi ? FlexPalette.inkPrimary : FlexPalette.primaryTeal
        amountLabel.snp.remakeConstraints { make in
            if multi {
                make.center.equalToSuperview()
                make.leading.greaterThanOrEqualTo(minusButton.snp.trailing).offset(12)
                make.trailing.lessThanOrEqualTo(plusButton.snp.leading).offset(-12)
            } else {
                make.center.equalToSuperview()
                make.leading.trailing.equalToSuperview()
            }
        }
    }

    private func bindPilot() {
        pilot.selectedAmount.stream.subscribe(onNext: { [weak self] amount in
            self?.amountLabel.text = RupeeAmountFormat.rupee(amount)
            self?.refreshAmountSection()
            self?.renderDetails()
        }).disposed(by: disposeBag)
        pilot.selectedTermIndex.stream.subscribe(onNext: { [weak self] _ in
            self?.renderDetails()
        }).disposed(by: disposeBag)
        pilot.bundle.stream.subscribe(onNext: { [weak self] bundle in
            self?.updateProductHeader(bundle)
            self?.refreshAmountSection()
            self?.renderDetails()
        }).disposed(by: disposeBag)
        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)
        pilot.isBusy.stream.subscribe(onNext: { [weak self] busy in
            guard let self else { return }
            self.applyButton.isEnabled = !busy
            self.applyButton.alpha = busy ? 0.55 : 1
        }).disposed(by: disposeBag)
        pilot.orderTipSignal.stream.subscribe(onNext: { [weak self] payload in
            guard let self else { return }
            FlexPendingDealSheet.present(on: self, message: payload.message,
                                         productId: self.productId, dealId: payload.dealId,
                                         code: payload.code)
        }).disposed(by: disposeBag)
    }

    private func renderDetails() {
        detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let term = pilot.currentTerm() else { return }
        let termSelectable = (pilot.currentTier()?.termRows.count ?? 0) > 1
        let rows = buildFieldRows(from: term, termSelectable: termSelectable)
        rows.forEach { model in
            let onSelect: (() -> Void)? = model.selectable ? { [weak self] in self?.presentTermPicker() } : nil
            detailStack.addArrangedSubview(FlexLoanWidgets.makeFieldRow(model, onSelect: onSelect, onHint: { [weak self] kind in
                self?.presentFieldHint(kind, scene: .product)
            }))
        }
    }

    private func buildFieldRows(from term: OfferTermRowShard, termSelectable: Bool) -> [FlexLoanFieldRowModel] {
        var rows: [FlexLoanFieldRowModel] = []
        if term.hasEMI {
            let emiCount = term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let termLabel = termSelectable ? FlexPhraseBook.Loan.selectEMIs : FlexPhraseBook.Loan.emis
            rows.append(.init(label: termLabel,
                              value: "\(emiCount) EMIs",
                              hintKind: nil,
                              selectable: termSelectable))
            if let stamp = term.emiRepayStamp, !stamp.isEmpty {
                rows.append(.init(label: FlexPhraseBook.Loan.emiDate, value: stamp, hintKind: nil, selectable: false))
            }
            if let amount = term.emiAmount, !amount.isEmpty {
                rows.append(.init(label: FlexPhraseBook.Loan.emiAmount,
                                  value: RupeeAmountFormat.rupee(amount),
                                  hintKind: nil,
                                  selectable: false))
            }
        } else {
            let days = term.showTerm ?? term.loanTerm ?? 0
            let termLabel = termSelectable ? FlexPhraseBook.Loan.selectTerm : FlexPhraseBook.Loan.loanTerm
            let termValue = termSelectable ? "\(days) Days" : "\(days) (Days)"
            rows.append(.init(label: termLabel, value: termValue, hintKind: nil, selectable: termSelectable))
        }
        appendAmountRow(&rows, label: FlexPhraseBook.Loan.amountReceived, raw: term.arrivalAmount ?? term.receiptAmount, hint: .amountReceived)
        appendAmountRow(&rows, label: FlexPhraseBook.Loan.serviceFee, raw: term.feeAmount, hint: .serviceFee)
        if term.interestAmount != "0", !(term.interestAmount ?? "").isEmpty {
            appendAmountRow(&rows, label: FlexPhraseBook.Loan.interest, raw: term.interestAmount, hint: .interest)
        }
        appendAmountRow(&rows, label: FlexPhraseBook.Loan.gst, raw: term.taxAmount, hint: nil)
        if let apply = term.applyStamp, !apply.isEmpty {
            rows.append(.init(label: FlexPhraseBook.Loan.applyDate, value: apply, hintKind: nil, selectable: false))
        }
        if let due = term.dueStamp, !due.isEmpty {
            rows.append(.init(label: FlexPhraseBook.Loan.dueDate, value: due, hintKind: nil, selectable: false))
        }
        return rows
    }

    private func appendAmountRow(_ rows: inout [FlexLoanFieldRowModel], label: String, raw: String?, hint: FlexFieldHintKind?) {
        guard let raw, !raw.isEmpty else { return }
        rows.append(.init(label: label, value: RupeeAmountFormat.indian(raw), hintKind: hint, selectable: false))
    }

    private func loadBankMask() {
        cofferStore.loadCards()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] cards in
                guard let mask = cards.first?.accountMask, !mask.isEmpty else { return }
                self?.bankMaskLabel.text = FlexCofferWidgets.groupedAccountNumber(mask)
            })
            .disposed(by: disposeBag)
    }

    private func presentTermPicker() {
        let options = pilot.termOptions()
        guard options.count > 1 else { return }
        FlexLedgerPickerSheet.present(on: self,
                                      title: pilot.currentTerm()?.hasEMI == true
                                        ? FlexPhraseBook.Loan.selectEMIs
                                        : FlexPhraseBook.Loan.selectTerm,
                                      options: options,
                                      selectedIndex: pilot.selectedTermIndex.value) { [weak self] index in
            self?.pilot.selectedTermIndex.accept(index)
        }
    }

    private func handleBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func toggleAgreement() {
        agreementCheck.isSelected.toggle()
    }

    @objc private func openTerms() {
        FlexLegalDocLaunch.open(.termsOfLoan, from: self)
    }

    @objc private func decrease() { pilot.adjustAmount(by: -1) }
    @objc private func increase() { pilot.adjustAmount(by: 1) }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !recommendCards.isEmpty else { return }
        flexNavBar.setTitleHidden(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !recommendCards.isEmpty, !decelerate else { return }
        flexNavBar.setTitleHidden(false)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard !recommendCards.isEmpty else { return }
        flexNavBar.setTitleHidden(false)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard !recommendCards.isEmpty else { return }
        flexNavBar.setTitleHidden(false)
    }

    private func rebuildRecommendPicker() {
        pickerStack.arrangedSubviews.forEach {
            pickerStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (index, card) in recommendCards.enumerated() {
            pickerStack.addArrangedSubview(makeRecommendRow(card: card, index: index))
        }
    }

    private func makeRecommendRow(card: OfferCardShard, index: Int) -> UIView {
        let wrap = FlexLoanWidgets.makeWhiteCard()
        let check = UIButton(type: .custom)
        check.tag = index
        check.setImage(FlexSlice.slice(FlexSliceCatalog.agreeMossIdle), for: .normal)
        check.setImage(FlexSlice.slice(FlexSliceCatalog.agreeSageMarked), for: .selected)
        check.isSelected = index == selectedRecommendIndex
        check.addTarget(self, action: #selector(recommendCheckTapped(_:)), for: .touchUpInside)

        let name = UILabel()
        name.text = card.productTitle ?? ""
        name.font = FlexTypography.medium(15)
        name.textColor = FlexPalette.inkPrimary

        let amount = UILabel()
        amount.text = RupeeAmountFormat.rupee(card.recommendAmount)
        amount.font = FlexTypography.bold(16)
        amount.textColor = FlexPalette.primaryTeal
        amount.textAlignment = .right

        wrap.addSubview(check)
        wrap.addSubview(name)
        wrap.addSubview(amount)
        check.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
            make.top.greaterThanOrEqualToSuperview().offset(16)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
        name.snp.makeConstraints { make in
            make.leading.equalTo(check.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        amount.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(name.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        wrap.isUserInteractionEnabled = true
        wrap.tag = index
        let tap = UITapGestureRecognizer(target: self, action: #selector(recommendRowTapped(_:)))
        wrap.addGestureRecognizer(tap)
        return wrap
    }

    @objc private func recommendRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        selectRecommendProduct(at: index)
    }

    @objc private func recommendCheckTapped(_ sender: UIButton) {
        if sender.isSelected {
            FlexToast.show(FlexPhraseBook.Hub.selectOneProduct)
            return
        }
        selectRecommendProduct(at: sender.tag)
    }

    private func selectRecommendProduct(at index: Int) {
        guard recommendCards.indices.contains(index) else { return }
        if index == selectedRecommendIndex { return }
        selectedRecommendIndex = index
        productId = recommendCards[index].productId ?? productId
        rebuildRecommendPicker()
        pilot.load(productId: productId)
    }

    @objc private func applyTapped() {
        guard agreementCheck.isSelected else {
            FlexToast.show(FlexPhraseBook.Loan.agreementRequired, on: view)
            return
        }
        guard let draft = pilot.submit() else { return }
        MintDealPipeline(host: self).execute(draft: draft, onSuccess: { [weak self] orderIds in
            guard let self else { return }
            let success = FlexLoanSuccessCanvas(orderIds: orderIds, leaveStyle: .hubHome)
            FlexRecommendLaunch.replaceTop(of: self.navigationController, with: success, animated: true)
        })
    }
}

extension FlexRootOrchestrator {
    func selectTab(index: Int) {
        (keyWindow?.rootViewController as? FlexDockShell)?.selectTab(index: index)
    }
}
