import UIKit
import SnapKit
import RxSwift

final class LedgerDetailCanvas: FlexBaseCanvas {
    private var dealId: String
    private var productId: String
    private let preferWithdraw: Bool
    private let store = LedgerOrderStore.shared
    private let disposeBag = DisposeBag()
    private var presentation: LedgerDetailPresentation?
    private var withdrawProduct: LedgerWithdrawProductShard?
    private var withdrawSelection: LedgerWithdrawSelection?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let primaryAction = FlexPrimaryButton()
    private let secondaryAction = FlexLedgerWidgets.makeOutlineButton(title: FlexPhraseBook.Ledger.deferAction)
    private let actionBar = UIView()

    init(dealId: String, productId: String, preferWithdraw: Bool = false) {
        self.dealId = dealId
        self.productId = productId
        self.preferWithdraw = preferWithdraw
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Ledger.detailTitle)
        layoutUI()
        loadDetail()
        NotificationCenter.default.addObserver(
            forName: .flexLedgerDetailNeedsRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadDetail()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Returning from harvest success (or any pushed page) — refresh status.
        if isMovingToParent == false, presentation != nil {
            loadDetail()
        }
    }

    private func layoutUI() {
        scrollView.showsVerticalScrollIndicator = false
        contentStack.axis = .vertical
        contentStack.spacing = 12
        primaryAction.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        secondaryAction.addTarget(self, action: #selector(deferTapped), for: .touchUpInside)
        actionBar.isHidden = true

        view.addSubview(scrollView)
        view.addSubview(actionBar)
        scrollView.addSubview(contentStack)
        actionBar.addSubview(secondaryAction)
        actionBar.addSubview(primaryAction)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionBar.snp.top)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-16 * 2)
        }
        actionBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(54 + 24)
        }
        secondaryAction.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(54)
            make.width.equalToSuperview().multipliedBy(0.42)
        }
        primaryAction.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.height.width.equalTo(secondaryAction)
        }
    }

    private func loadDetail() {
        // 6230003 Know More — open withdraw detail directly (Kiva orderTypeNumber=32).
        if preferWithdraw {
            loadWithdrawOnly()
            return
        }
        store.fetchDetail(dealId: dealId, productId: productId)
            .flatMap { [store, dealId, productId] shard -> Single<(LedgerDetailShard, LedgerWithdrawProductShard?)> in
                guard shard.dealState == 32 else {
                    return .just((shard, nil))
                }
                let resolvedId = shard.dealId?.trimmingCharacters(in: .whitespacesAndNewlines)
                let withdrawDealId = (resolvedId?.isEmpty == false ? resolvedId! : dealId)
                return store.fetchWithdrawDetail(dealId: withdrawDealId, productId: productId)
                    .map { (shard, $0) }
                    .catchErrorJustReturn((shard, nil))
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] shard, withdraw in
                guard let self else { return }
                self.adoptIdentifiers(fromDetail: shard, withdraw: withdraw)
                if let withdraw {
                    self.applyWithdraw(withdraw)
                } else {
                    self.withdrawProduct = nil
                    self.withdrawSelection = nil
                    // Status 32 without withdraw payload: show facts, hide Withdraw CTA.
                    self.applyPresentation(
                        LedgerDetailBlueprint.fromDetail(shard, withdrawAvailable: shard.dealState != 32)
                    )
                }
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? "Load failed")
            })
            .disposed(by: disposeBag)
    }

    /// 6230003 Know More — Kiva opens withdraw detail with productId only.
    private func loadWithdrawOnly() {
        store.fetchWithdrawDetail(dealId: dealId, productId: productId)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] withdraw in
                guard let self else { return }
                self.adoptIdentifiers(fromDetail: nil, withdraw: withdraw)
                self.applyWithdraw(withdraw)
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? "Load failed")
            })
            .disposed(by: disposeBag)
    }

    private func adoptIdentifiers(fromDetail shard: LedgerDetailShard?, withdraw: LedgerWithdrawProductShard?) {
        if let id = shard?.dealId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            dealId = id
        } else if let id = withdraw?.dealId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            dealId = id
        }
        if let pid = shard?.productId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            productId = pid
        } else if let pid = withdraw?.productId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            productId = pid
        }
    }

    private func applyWithdraw(_ withdraw: LedgerWithdrawProductShard) {
        withdrawProduct = withdraw
        let tierIndex = max(0, withdraw.amountTiers.count - 1)
        let termCount = withdraw.amountTiers.indices.contains(tierIndex)
            ? withdraw.amountTiers[tierIndex].termOptions.count
            : 1
        let termIndex = max(0, termCount - 1)
        withdrawSelection = LedgerWithdrawSelection(
            product: withdraw,
            tierIndex: tierIndex,
            termIndex: termIndex
        )
        applyPresentation(LedgerDetailBlueprint.fromWithdraw(withdrawSelection!))
    }

    private func refreshWithdrawPresentation() {
        guard let selection = withdrawSelection else { return }
        applyPresentation(LedgerDetailBlueprint.fromWithdraw(selection))
    }

    private func applyPresentation(_ model: LedgerDetailPresentation) {
        presentation = model
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let banner = model.bannerHint {
            contentStack.addArrangedSubview(FlexLedgerWidgets.makeHintBanner(banner))
        }

        let card = FlexLedgerWidgets.makeDetailCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 14
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        cardStack.addArrangedSubview(FlexLedgerWidgets.makeStatusPillRow(status: model.statusCode))
        cardStack.addArrangedSubview(FlexLedgerWidgets.makeProductHeader(
            name: model.productTitle,
            amount: model.principal,
            logoURL: model.productLogoURL,
            showsChevron: model.amountSelectable,
            onTap: model.amountSelectable ? { [weak self] in self?.presentAmountPicker() } : nil
        ))

        let fieldStack = UIStackView()
        fieldStack.axis = .vertical
        fieldStack.spacing = 8
        model.rows.forEach { row in
            let onSelect: (() -> Void)? = row.selectKind == .term ? { [weak self] in self?.presentTermPicker() } : nil
            fieldStack.addArrangedSubview(FlexLedgerWidgets.makeFieldRow(row, onSelect: onSelect, onHint: { [weak self] kind in
                self?.presentFieldHint(kind, scene: .orderDetail)
            }))
        }
        cardStack.addArrangedSubview(fieldStack)
        contentStack.addArrangedSubview(card)

        if let bank = model.bankMask, model.showsBankBar {
            let formatted = FlexCofferWidgets.groupedAccountNumber(bank)
            contentStack.addArrangedSubview(FlexLedgerWidgets.makeBankBar(mask: formatted))
        }
        if model.showsUPIWarning {
            contentStack.addArrangedSubview(FlexLedgerWidgets.makeUPIWarning())
        }
        if let note = model.footerNote {
            contentStack.addArrangedSubview(FlexLedgerWidgets.makeFooterNote(note))
        }

        configureActions(model.action)
    }

    private func configureActions(_ action: LedgerDetailAction) {
        switch action {
        case .none:
            actionBar.isHidden = true
            scrollView.contentInset.bottom = 0
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.bottom.equalToSuperview()
            }
        case .withdraw:
            actionBar.isHidden = false
            scrollView.contentInset.bottom = 12
            secondaryAction.isHidden = true
            primaryAction.setTitle(FlexPhraseBook.Ledger.withdraw, for: .normal)
            primaryAction.flexRoundCorners(27)
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(actionBar.snp.top)
            }
            primaryAction.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
                make.height.equalTo(54)
            }
        case .repay:
            actionBar.isHidden = false
            scrollView.contentInset.bottom = 12
            secondaryAction.isHidden = true
            primaryAction.setTitle(FlexPhraseBook.Ledger.repay, for: .normal)
            primaryAction.flexRoundCorners(27)
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(actionBar.snp.top)
            }
            primaryAction.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
                make.height.equalTo(54)
            }
        case .repayAndDefer:
            actionBar.isHidden = false
            scrollView.contentInset.bottom = 12
            secondaryAction.isHidden = false
            secondaryAction.setTitle(FlexPhraseBook.Ledger.deferAction, for: .normal)
            primaryAction.setTitle(FlexPhraseBook.Ledger.repay, for: .normal)
            primaryAction.flexRoundCorners(27)
            secondaryAction.flexRoundCorners(27)
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(actionBar.snp.top)
            }
            primaryAction.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
                make.height.equalTo(54)
                make.width.equalToSuperview().multipliedBy(0.42)
            }
        case .continueSubmit:
            actionBar.isHidden = false
            scrollView.contentInset.bottom = 12
            secondaryAction.isHidden = true
            primaryAction.setTitle(FlexPhraseBook.Ledger.continueSubmit, for: .normal)
            primaryAction.flexRoundCorners(27)
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(actionBar.snp.top)
            }
            primaryAction.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
                make.height.equalTo(54)
            }
        case .changeBank:
            actionBar.isHidden = false
            scrollView.contentInset.bottom = 12
            secondaryAction.isHidden = true
            primaryAction.setTitle(FlexPhraseBook.Ledger.changeBank, for: .normal)
            primaryAction.flexRoundCorners(27)
            scrollView.snp.remakeConstraints { make in
                make.top.equalTo(contentTopAnchor()).offset(16)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(actionBar.snp.top)
            }
            primaryAction.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
                make.height.equalTo(54)
            }
        }
    }

    private func presentAmountPicker() {
        guard let product = withdrawProduct else { return }
        let options = product.amountTiers.map { RupeeAmountFormat.rupee($0.principal) }
        guard options.count > 1 else { return }
        FlexLedgerPickerSheet.present(
            on: self,
            title: FlexPhraseBook.Ledger.pickAmountTitle,
            options: options,
            selectedIndex: withdrawSelection?.tierIndex ?? 0
        ) { [weak self] index in
            guard let self, let product = self.withdrawProduct else { return }
            let termIndex = min(
                self.withdrawSelection?.termIndex ?? 0,
                max(0, product.amountTiers[index].termOptions.count - 1)
            )
            self.withdrawSelection = LedgerWithdrawSelection(
                product: product,
                tierIndex: index,
                termIndex: termIndex
            )
            self.refreshWithdrawPresentation()
        }
    }

    private func presentTermPicker() {
        guard let selection = withdrawSelection, let tier = selection.tier else { return }
        let options = tier.termOptions.map { term in
            let emiCount = term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !emiCount.isEmpty { return "\(emiCount) EMIs" }
            let days = term.showTerm ?? term.loanTerm ?? 0
            return "\(days) (Days)"
        }
        guard options.count > 1 else { return }
        let hasEMI = tier.termOptions.contains { term in
            !(term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        }
        FlexLedgerPickerSheet.present(
            on: self,
            title: hasEMI ? FlexPhraseBook.Loan.selectEMIs : FlexPhraseBook.Ledger.pickTermTitle,
            options: options,
            selectedIndex: selection.termIndex
        ) { [weak self] index in
            guard let self, let product = self.withdrawProduct else { return }
            self.withdrawSelection = LedgerWithdrawSelection(
                product: product,
                tierIndex: selection.tierIndex,
                termIndex: index
            )
            self.refreshWithdrawPresentation()
        }
    }

    @objc private func primaryTapped() {
        switch presentation?.action {
        case .withdraw: withdrawDeal()
        case .repay, .repayAndDefer: openRepayLink()
        case .continueSubmit: resumeIncompleteDeal()
        case .changeBank: openBankEdit()
        default: break
        }
    }

    /// Status 36 — jump straight to bank edit form (not the card list).
    private func openBankEdit() {
        let canvas = VaultEditCardCanvas()
        canvas.onUpdated = { [weak self] in self?.loadDetail() }
        navigationController?.pushViewController(canvas, animated: true)
    }

    @objc private func deferTapped() {
        store.requestExtend(dealId: dealId, payAccountNumber: presentation?.bankMask)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] shard in
                self?.openConnect(shard, title: FlexPhraseBook.Ledger.deferWebTitle,
                                  missingMessage: FlexPhraseBook.Ledger.deferLinkMissing)
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func openRepayLink() {
        store.fetchRepayLink(dealId: dealId, payAccountNumber: presentation?.bankMask)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] shard in
                self?.openConnect(shard, title: FlexPhraseBook.Ledger.repayWebTitle,
                                  missingMessage: FlexPhraseBook.Ledger.repayLinkMissing)
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    /// LoanEase parity: only http(s) → in-app repay/defer H5; otherwise missing toast (never Safari).
    private func openConnect(_ shard: RepayLinkShard, title: String, missingMessage: String) {
        let raw = shard.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let scheme = URL(string: raw)?.scheme?.lowercased() ?? ""
        guard !raw.isEmpty, let url = URL(string: raw), scheme == "http" || scheme == "https" else {
            FlexToast.show(missingMessage)
            return
        }
        navigationController?.pushViewController(
            FlexLedgerLinkCanvas(url: url, title: title),
            animated: true
        )
    }

    private func withdrawDeal() {
        let amount = withdrawSelection?.loanAmount ?? presentation?.principal ?? ""
        let term = withdrawSelection?.loanTerm ?? ""
        guard !amount.isEmpty, !term.isEmpty else {
            FlexToast.show(FlexPhraseBook.Ledger.withdraw)
            return
        }
        store.requestWithdraw(dealId: dealId, loanAmount: amount, loanTerm: term)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                self?.presentWithdrawSuccess()
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func presentWithdrawSuccess() {
        FlexIllustratedSheet.present(
            on: self,
            art: FlexSliceCatalog.dialogWithdrawArt,
            message: FlexPhraseBook.Ledger.withdrawSuccessBody,
            confirmTitle: FlexPhraseBook.Dialog.confirm,
            showsCancel: false,
            onConfirm: { [weak self] in
                self?.loadDetail()
            }
        )
    }

    private func resumeIncompleteDeal() {
        MintDealPipeline(host: self).resumeExistingDeal(orderId: dealId, onSuccess: { [weak self] orderIds in
            guard let self else { return }
            // Back returns to this detail — leaveStyle refreshes status (no longer 待抓取).
            self.navigationController?.pushViewController(
                FlexLoanSuccessCanvas(orderIds: orderIds, leaveStyle: .orderDetail),
                animated: true
            )
        }, onAbort: { [weak self] in
            self?.loadDetail()
        })
    }
}
