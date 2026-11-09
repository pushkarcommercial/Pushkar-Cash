import RxSwift
import UIKit

/// First-loan automatic batch submission when the home response selects `system`.
/// Permission abort keeps the session armed so Apply retries auto-order (secondary location sheet).
final class MintHubAutoOrderPilot {
    let toastSignal = FlexSignal<String>()
    let openLoanSuccess = FlexSignal<[String]>()

    private(set) var isArmed = false
    private var isRunning = false
    /// Success / hard failure — no more auto-order this login session.
    private var hasAttemptedSession = false
    /// Silent home auto-fire at most once; Apply tap can still retry after permission abort.
    private var didAutoFire = false
    private var matchingOverlay: UIView?
    private var bag = DisposeBag()
    private let store = MintHubStore.shared

    func evaluateAfterRefresh(snapshot: HubSnapshotShard, evaluateInitial: Bool = true) {
        _ = evaluateInitial
        let eligible = snapshot.memberState == HubMemberPhase.creditReady.rawValue
            && snapshot.hasActiveDeal != true
            && snapshot.prefersSystemAutoPlace
        isArmed = eligible && !hasAttemptedSession && !isRunning
    }

    func maybeStart(from host: UIViewController) {
        guard isArmed, !isRunning, !didAutoFire, !hasAttemptedSession else { return }
        beginAutoPlace(from: host)
    }

    @discardableResult
    func handlePrimaryTap(from host: UIViewController) -> Bool {
        guard isArmed, !isRunning else { return false }
        beginAutoPlace(from: host)
        return true
    }

    func markConsumed() {
        isArmed = false
        isRunning = false
        hasAttemptedSession = true
        didAutoFire = true
    }

    func resetSession() {
        hideMatchingOverlay()
        isArmed = false
        isRunning = false
        hasAttemptedSession = false
        didAutoFire = false
        bag = DisposeBag()
    }

    private func beginAutoPlace(from host: UIViewController) {
        guard !isRunning else { return }
        isRunning = true
        isArmed = false
        didAutoFire = true
        // 72 — fire when auto-order starts (not after geo), so location abort is still counted.
        PulseBeaconRecorder.shared.stamp(.autoApplyTriggered)
        matchingOverlay = FlexRecommendMatchOverlay.show(on: host.view)

        store.fetchAutoRecommend()
            .timeout(10, scheduler: MainScheduler.instance)
            .observeOn(MainScheduler.instance)
            .do(onSuccess: { [weak self] _ in self?.hideMatchingOverlay() },
                onError: { [weak self] _ in self?.hideMatchingOverlay() })
            .flatMap { [weak self] envelope -> Single<[MintDealDraft]> in
                guard let self else { return .just([]) }
                guard envelope.pulseCode == 200 else {
                    throw PulseWireFault.business(code: envelope.pulseCode ?? -1,
                                                  message: envelope.businessMessage)
                }
                let cards = envelope.cards.filter { !($0.productId ?? "").isEmpty }
                guard !cards.isEmpty else { return .just([]) }
                return Observable.from(cards)
                    .concatMap { card -> Observable<MintDealDraft> in
                        guard let productId = card.productId, !productId.isEmpty else {
                            throw PulseWireFault.business(code: -1, message: FlexPhraseBook.Loan.amountOutOfRange)
                        }
                        if let draft = Self.draft(from: card) { return .just(draft) }
                        return self.store.loadOfferTermBundle(productId: productId)
                            .map { bundle -> MintDealDraft in
                                guard let draft = Self.draft(productId: productId, bundle: bundle) else {
                                    throw PulseWireFault.business(code: -1, message: FlexPhraseBook.Loan.amountOutOfRange)
                                }
                                return draft
                            }
                            .asObservable()
                    }
                    .toArray()
                    .asSingle()
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self, weak host] drafts in
                guard let self, let host else { return }
                guard !drafts.isEmpty else {
                    self.showResult(FlexRecommendEmptyCanvas(), from: host)
                    return
                }
                MintDealPipeline(host: host).execute(drafts: drafts, autoOrder: true,
                                                     onSuccess: { [weak self] orderIds in
                    guard let self else { return }
                    self.markConsumed()
                    self.openLoanSuccess.accept(orderIds)
                }, onAbort: { [weak self] in
                    // Location / contacts abort — keep armed so Apply retries auto pipeline
                    // (already-denied location → secondary settings sheet).
                    self?.isRunning = false
                    self?.isArmed = true
                })
            }, onError: { [weak self, weak host] error in
                if case PulseWireFault.business(let code, _) = error, code == 4102007,
                   let self, let host {
                    // 据量 H5 only when home status is 51 — auto-order is status 20, so error page only.
                    self.showResult(FlexRecommendEmptyCanvas(), from: host)
                } else {
                    self?.finishWithFailure((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
                }
            })
            .disposed(by: bag)
    }

    private static func draft(from card: OfferCardShard) -> MintDealDraft? {
        guard let productId = card.productId, !productId.isEmpty,
              let bundle = card.termBundle else { return nil }
        return draft(productId: productId, bundle: bundle)
    }

    private static func draft(productId: String, bundle: OfferTermBundleShard) -> MintDealDraft? {
        guard !bundle.tiers.isEmpty else { return nil }
        let tier = bundle.tiers[bundle.highestAmountIndex()]
        guard !tier.termRows.isEmpty else { return nil }
        let term = tier.termRows[bundle.highestTermIndex(in: tier)]
        let amount = RupeeAmountFormat.digits(from: tier.loanAmount)
        guard !amount.isEmpty, let days = term.loanTerm ?? term.showTerm, days > 0 else { return nil }
        return MintDealDraft(productId: productId, loanAmount: amount, showTerm: String(days))
    }

    private func finishWithFailure(_ message: String) {
        hideMatchingOverlay()
        markConsumed()
        toastSignal.accept(message)
    }

    private func showResult(_ canvas: UIViewController, from host: UIViewController) {
        hideMatchingOverlay()
        markConsumed()
        canvas.hidesBottomBarWhenPushed = true
        host.navigationController?.pushViewController(canvas, animated: false)
    }

    private func hideMatchingOverlay() {
        matchingOverlay?.removeFromSuperview()
        matchingOverlay = nil
    }
}
