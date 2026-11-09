import UIKit
import SnapKit
import RxSwift

/// Where Back / leave from the post-submit success page should land.
enum FlexLoanSuccessLeaveStyle {
    /// Product apply / auto-order — home tab root + hub refresh (never back to apply).
    case hubHome
    /// Order-detail harvest resume — pop to detail; detail reloads on appear.
    case orderDetail
}

/// Loan details after order submit — one `/order/detailV2` per returned order id.
final class FlexLoanSuccessCanvas: FlexBaseCanvas {
    private let orderIds: [String]
    private let leaveStyle: FlexLoanSuccessLeaveStyle
    private let store = LedgerOrderStore.shared
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let descWrap = UIView()
    private let cardsHost = UIStackView()
    private let feedbackButton = UIButton(type: .system)
    private let confirmButton = FlexPrimaryButton()

    init(orderIds: [String], leaveStyle: FlexLoanSuccessLeaveStyle = .hubHome) {
        self.orderIds = orderIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.leaveStyle = leaveStyle
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    /// Single-order resume / legacy entry.
    convenience init(dealId: String, productId: String = "", leaveStyle: FlexLoanSuccessLeaveStyle = .hubHome) {
        _ = productId
        self.init(orderIds: dealId.isEmpty ? [] : [dealId], leaveStyle: leaveStyle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Loan.loanDetailsTitle)
        flexNavBar.onBack = { [weak self] in self?.leave() }
        layoutUI()
        loadDetails()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Apply-flow leave goes home — block swipe-back onto the apply page.
        if leaveStyle == .hubHome {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func layoutUI() {
        scrollView.showsVerticalScrollIndicator = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill

        cardsHost.axis = .vertical
        cardsHost.spacing = 12

        let icon = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.dialogSuccessCrest))
        icon.contentMode = .scaleAspectFit

        let headline = UILabel()
        headline.text = FlexPhraseBook.Loan.successHeadline
        headline.font = FlexTypography.bold(21)
        headline.textColor = FlexPalette.inkPrimary
        headline.textAlignment = .center

        let desc = UILabel()
        desc.text = FlexPhraseBook.Loan.successDesc
        desc.font = FlexTypography.regular(12)
        desc.textColor = FlexPalette.inkTertiary
        desc.numberOfLines = 0
        desc.textAlignment = .center
        descWrap.addSubview(desc)
        desc.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(28 - 12)
        }

        feedbackButton.setTitle(FlexPhraseBook.Coffer.feedback, for: .normal)
        feedbackButton.setTitleColor(FlexPalette.inkSecondary, for: .normal)
        feedbackButton.titleLabel?.font = FlexTypography.medium(18)
        feedbackButton.addTarget(self, action: #selector(openFeedback), for: .touchUpInside)

        confirmButton.setTitle(FlexPhraseBook.Dialog.confirm, for: .normal)
        confirmButton.titleLabel?.font = FlexTypography.bold(18)
        confirmButton.flexRoundCorners(12)
        confirmButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        [icon, headline, descWrap, cardsHost].forEach { contentStack.addArrangedSubview($0) }
        icon.snp.makeConstraints { $0.height.equalTo(128) }
        contentStack.setCustomSpacing(11, after: icon)
        contentStack.setCustomSpacing(10, after: headline)
        contentStack.setCustomSpacing(15, after: descWrap)

        let actionBar = UIView()
        actionBar.backgroundColor = .white
        actionBar.layer.shadowColor = UIColor.black.cgColor
        actionBar.layer.shadowOpacity = 0.06
        actionBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        actionBar.layer.shadowRadius = 6

        let topHairline = UIView()
        topHairline.backgroundColor = FlexPalette.fieldBorder

        actionBar.addSubview(topHairline)
        actionBar.addSubview(feedbackButton)
        actionBar.addSubview(confirmButton)

        view.addSubview(scrollView)
        view.addSubview(actionBar)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionBar.snp.top)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12))
            make.width.equalTo(scrollView).offset(-24)
        }
        actionBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        topHairline.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        feedbackButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalTo(actionBar.safeAreaLayoutGuide).offset(-12)
            make.height.equalTo(58)
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(feedbackButton)
            make.leading.equalTo(feedbackButton.snp.trailing).offset(10)
            make.height.equalTo(58)
            make.width.equalToSuperview().multipliedBy(0.55)
        }
    }

    private func loadDetails() {
        guard !orderIds.isEmpty else {
            FlexToast.show(FlexPhraseBook.Network.busy)
            return
        }
        let requests: [Observable<LedgerDetailShard>] = orderIds.map { [store] orderId in
            store.fetchDetail(dealId: orderId, productId: "")
                .asObservable()
                .catchError { _ in Observable<LedgerDetailShard>.empty() }
        }
        Observable.concat(requests)
            .toArray()
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] shards in
                guard let self else { return }
                self.cardsHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
                shards.forEach { self.cardsHost.addArrangedSubview(self.makeOrderCard(from: $0)) }
                if shards.isEmpty {
                    FlexToast.show(FlexPhraseBook.Network.busy)
                }
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func makeOrderCard(from shard: LedgerDetailShard) -> UIView {
        let presentation = LedgerDetailBlueprint.fromSuccess(shard)
        let card = FlexLoanWidgets.makeWhiteCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        stack.addArrangedSubview(FlexLedgerWidgets.makeStatusPillRow(status: presentation.statusCode))
        stack.addArrangedSubview(FlexLedgerWidgets.makeProductHeader(
            name: presentation.productTitle,
            amount: presentation.principal,
            logoURL: presentation.productLogoURL
        ))

        let fieldStack = UIStackView()
        fieldStack.axis = .vertical
        fieldStack.spacing = 8
        presentation.rows.forEach { row in
            fieldStack.addArrangedSubview(FlexLedgerWidgets.makeFieldRow(row, onHint: { [weak self] kind in
                self?.presentFieldHint(kind, scene: .success)
            }))
        }
        stack.addArrangedSubview(fieldStack)
        return card
    }

    private func leave() {
        switch leaveStyle {
        case .hubHome:
            NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
            FlexRootOrchestrator.shared.returnToHubHome()
            FlexRatingCoordinator.maybePresent()
        case .orderDetail:
            NotificationCenter.default.post(name: .flexLedgerDetailNeedsRefresh, object: nil)
            navigationController?.popViewController(animated: true)
            FlexRatingCoordinator.maybePresent()
        }
    }

    /// Confirm — always return to home tab root, then rating guide if allowed.
    @objc private func done() {
        NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
        FlexRootOrchestrator.shared.returnToHubHome()
        FlexRatingCoordinator.maybePresent()
    }

    /// Feedback exit skips this success page — back/submit go hub home + refresh.
    @objc private func openFeedback() {
        NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
        let feedback = CofferFeedbackCanvas(exitToHubHome: true)
        navigationController?.pushViewController(feedback, animated: true)
        FlexRatingCoordinator.maybePresent(from: feedback)
    }
}

extension Notification.Name {
    static let flexLedgerDetailNeedsRefresh = Notification.Name("flex.ledger.detailNeedsRefresh")
}
