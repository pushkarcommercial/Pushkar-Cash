import UIKit
import SnapKit
import RxSwift

/// Precise-recommend matching — loading UI, no back, 10s cap, no push animation.
/// Result routing mirrors LoanEase `LERecommendLaunch`; UI stays Flex empty layout.
final class FlexRecommendMatchCanvas: FlexBaseCanvas {
    var onFinished: (() -> Void)?

    private let store = MintHubStore.shared
    private let disposeBag = DisposeBag()
    private var didStart = false
    private var didFinish = false
    private var didResolve = false
    /// Captured before request — LoanEase `homeSnapshot` / `promptCopy` + status 80.
    private var homeSnapshot: HubSnapshotShard?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Full-screen matching card — hide base nav (no back affordance).
        flexNavBar.isHidden = true
        view.backgroundColor = FlexDialogMetrics.scrim
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        layoutCard()
        startRecommendIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        startRecommendIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if isMovingFromParent || isBeingDismissed {
            finishIfNeeded()
        }
    }

    private func layoutCard() {
        let card = Self.makeMatchingCard()
        view.addSubview(card)
        card.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(FlexDialogMetrics.cardHorizontalInset)
            make.trailing.equalToSuperview().offset(-FlexDialogMetrics.cardHorizontalInset)
        }
    }

    static func makeMatchingCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.flexRoundCorners(FlexDialogMetrics.cardCorner)

        let art = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.matchingDialogArt))
        art.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = FlexPhraseBook.Hub.matchingTitle
        title.font = FlexTypography.bold(20)
        title.textAlignment = .center
        title.textColor = FlexPalette.inkPrimary
        title.numberOfLines = 0

        let body = UILabel()
        body.text = FlexPhraseBook.Hub.matchingBody
        body.font = FlexTypography.regular(14)
        body.textColor = FlexPalette.inkSecondary
        body.textAlignment = .center
        body.numberOfLines = 0

        [art, title, body].forEach { card.addSubview($0) }
        art.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(FlexDialogMetrics.iconSize)
        }
        title.snp.makeConstraints { make in
            make.top.equalTo(art.snp.bottom).offset(FlexDialogMetrics.iconToTitle)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        body.snp.makeConstraints { make in
            make.top.equalTo(title.snp.bottom).offset(FlexDialogMetrics.titleToBody)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
        }
        return card
    }

    private func startRecommendIfNeeded() {
        guard !didStart else { return }
        didStart = true
        homeSnapshot = store.lastSnapshot
        store.fetchManualRecommend()
            .timeout(10, scheduler: MainScheduler.instance)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] envelope in
                self?.handleEnvelope(envelope)
            }, onError: { [weak self] error in
                self?.handleFailure(error)
            })
            .disposed(by: disposeBag)
    }

    private func handleEnvelope(_ envelope: OfferDeckEnvelope) {
        guard !didResolve else { return }
        didResolve = true
        let code = envelope.pulseCode ?? 0
        let cards = envelope.quotaCards
        // 据量 H5: rejectH5 configured + 4102007 + no products.
        if code == 4102007, cards.isEmpty {
            presentRejectVolumeOrEmpty()
            return
        }
        let noData = cards.isEmpty || (code != 200 && code != 0)
        if noData {
            presentPendingRepayment()
            return
        }
        presentApply(cards)
    }

    private func handleFailure(_ error: Error) {
        guard !didResolve else { return }
        didResolve = true
        // Timeout → error page; 4102007 (no products) → H5 / error; else → pending-repay.
        if let rx = error as? RxError, case .timeout = rx {
            presentEmpty()
            return
        }
        if case PulseWireFault.business(let code, _) = error, code == 4102007 {
            presentRejectVolumeOrEmpty()
            return
        }
        presentPendingRepayment()
    }

    /// Success with products → product apply page.
    private func presentApply(_ cards: [OfferCardShard]) {
        let apply = FlexRecommendApplyCanvas(cards: cards)
        apply.hidesBottomBarWhenPushed = true
        FlexRecommendLaunch.replaceTop(of: navigationController, with: apply, animated: false)
        finishIfNeeded()
    }

    /// 据量 H5 when cached `rejectH5` exists; otherwise empty recommend page.
    private func presentRejectVolumeOrEmpty() {
        if let h5 = FlexRejectVolumeLaunch.makeCanvasIfAvailable() {
            FlexRecommendLaunch.replaceTop(of: navigationController, with: h5, animated: false)
            finishIfNeeded()
            return
        }
        presentEmpty()
    }

    private func presentEmpty() {
        let empty = FlexRecommendEmptyCanvas()
        empty.hidesBottomBarWhenPushed = true
        FlexRecommendLaunch.replaceTop(of: navigationController, with: empty, animated: false)
        finishIfNeeded()
    }

    /// Pending tip — copy from home `promptCopy`; View Now only when `userStatus == 80`.
    private func presentPendingRepayment() {
        let snap = homeSnapshot
        let homeCopy = (snap?.promoCopy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isStatus80 = snap?.memberState == HubMemberPhase.processing.rawValue
        let pending = FlexRecommendPendingCanvas(
            message: homeCopy,
            showsAction: isStatus80,
            onAction: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: false)
                FlexRootOrchestrator.shared.openLedger(tab: .pendingRepay)
            }
        )
        pending.hidesBottomBarWhenPushed = true
        FlexRecommendLaunch.replaceTop(of: navigationController, with: pending, animated: false)
        finishIfNeeded()
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        FlexRecommendLaunch.markIdle()
        onFinished?()
    }
}

enum FlexRecommendMatchOverlay {
    static func show(on host: UIView) -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = FlexDialogMetrics.scrim
        let card = FlexRecommendMatchCanvas.makeMatchingCard()
        host.addSubview(overlay)
        overlay.addSubview(card)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        card.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(FlexDialogMetrics.cardHorizontalInset)
            make.trailing.equalToSuperview().offset(-FlexDialogMetrics.cardHorizontalInset)
        }
        return overlay
    }
}
