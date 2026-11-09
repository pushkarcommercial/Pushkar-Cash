import Foundation
import UIKit
import RxSwift

enum HubMemberPhase: Int {
    case verifyPending = 10
    case creditReady = 20
    case orderPending = 30
    case withdrawPending = 32
    case reborrowReady = 41
    /// 据量 / Accurate Recommendation (`userStatus` 51).
    case rejectVolume = 51
    case processing = 80
    case overdue = 81
    case other = 100

    /// Home banner CTA — Feishu home status table.
    var bannerButtonTitle: String {
        switch self {
        case .verifyPending, .creditReady, .processing, .rejectVolume, .other:
            return FlexPhraseBook.Hub.apply
        case .overdue:
            return FlexPhraseBook.Hub.payOverdue
        case .reborrowReady:
            return FlexPhraseBook.Hub.changeBankAccount
        case .withdrawPending:
            return FlexPhraseBook.Hub.getLoan
        case .orderPending:
            return FlexPhraseBook.Hub.submitApplication
        }
    }

    var usesRecommend: Bool {
        switch self {
        case .creditReady, .processing, .rejectVolume, .other:
            return true
        default:
            return false
        }
    }

    var bannerMessage: String {
        switch self {
        case .verifyPending: return FlexPhraseBook.Hub.kycBanner
        case .creditReady: return FlexPhraseBook.Hub.readyBanner
        case .orderPending: return FlexPhraseBook.Hub.applyPrompt
        case .withdrawPending: return FlexPhraseBook.Hub.withdrawPending
        case .reborrowReady: return FlexPhraseBook.Ledger.noteChangeBank
        case .rejectVolume: return FlexPhraseBook.Hub.rejectVolumeBanner
        case .processing: return FlexPhraseBook.Ledger.bannerRepay
        case .overdue: return FlexPhraseBook.Ledger.noteOverdue
        case .other: return FlexPhraseBook.Hub.statusPending
        }
    }

    var overdueTint: Bool { self == .overdue }
}

enum HubBannerVisual {
    static let placeholderAmount = "500000"
    static let placeholderRate = "0.07"
    static let placeholderTerm = "360"

    static func amountText(_ raw: String?) -> String {
        let digits = RupeeAmountFormat.digits(from: raw)
        let value = digits.isEmpty ? placeholderAmount : digits
        return RupeeAmountFormat.rupee(value)
    }

    static func rateText(_ raw: String?) -> String {
        let numeric = (raw ?? "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = numeric.isEmpty ? placeholderRate : numeric
        guard let value = Double(source) else {
            return "\(placeholderRate) \(FlexPhraseBook.Hub.ratePerDay)"
        }
        // API / placeholder already use percent units (e.g. 0.07 → "0.07 %/day").
        let formatted = String(format: "%g", value)
        return "\(formatted) \(FlexPhraseBook.Hub.ratePerDay)"
    }

    static func termText(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().contains("day") { return trimmed }
        let digits = RupeeAmountFormat.digits(from: trimmed)
        let days = digits.isEmpty ? placeholderTerm : digits
        return "\(days) \(FlexPhraseBook.Hub.termDays)"
    }
}

final class MintHubPilot {
    let snapshot = FlexRelay<HubSnapshotShard?>(nil)
    let offers = FlexRelay<[OfferCardShard]>([])
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()
    let needsVerify = FlexSignal<[VerifyStageShard]>()
    /// Home message strip under the loan card — always on; prefer API `promptCopy`, else local status copy.
    let showKycBanner = FlexRelay(true)
    let statusBannerText = FlexRelay(FlexPhraseBook.Hub.kycBanner)
    let statusBannerTappable = FlexRelay(true)
    let bannerButtonTitle = FlexRelay(FlexPhraseBook.Hub.apply)
    let bannerButtonOverdue = FlexRelay(false)
    let quotaAmountText = FlexRelay(HubBannerVisual.amountText(nil))
    let rateText = FlexRelay(HubBannerVisual.rateText(nil))
    let termText = FlexRelay(HubBannerVisual.termText(nil))
    let openRecommend = FlexSignal<Bool>()
    let openOrderDetail = FlexSignal<(dealId: String, productId: String)>()
    let openOrdersTab = FlexSignal<LedgerTabKind>()
    let openLoanSuccess = FlexSignal<[String]>()

    private let store = MintHubStore.shared
    private let autoOrderPilot = MintHubAutoOrderPilot()
    private let disposeBag = DisposeBag()
    private let refreshGate = SerialDisposable()

    init() {
        autoOrderPilot.toastSignal.stream.subscribe(onNext: { [weak self] in
            self?.toastSignal.accept($0)
        }).disposed(by: disposeBag)
        autoOrderPilot.openLoanSuccess.stream.subscribe(onNext: { [weak self] payload in
            self?.openLoanSuccess.accept(payload)
        }).disposed(by: disposeBag)
    }

    func refreshHub(evaluateAutoOrder: Bool = true) {
        isBusy.accept(true)
        FlexSpinnerOverlay.beginRequest()
        let work = store.loadSnapshot()
            .observeOn(MainScheduler.instance)
            .do(onDispose: { FlexSpinnerOverlay.endRequest() })
            .subscribe(onSuccess: { [weak self] snap in
                guard let self else { return }
                self.applyMemberPhase(snap)
                // Arm before snapshot publish so `runAutoOrderIfNeeded` sees fresh eligibility.
                self.autoOrderPilot.evaluateAfterRefresh(snapshot: snap, evaluateInitial: evaluateAutoOrder)
                self.snapshot.accept(snap)
                self.isBusy.accept(false)
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                // Home tab reappear cancels the prior snapshot request — ignore that error.
                guard !error.flex_isRequestCancelled else { return }
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? FlexPhraseBook.Hub.loadFailed)
            })
        refreshGate.disposable = work
    }

    func runAutoOrderIfNeeded(from host: UIViewController) {
        autoOrderPilot.maybeStart(from: host)
    }

    func resetAutoOrderSession() {
        autoOrderPilot.resetSession()
    }

    func routePrimaryApply(from host: UIViewController) {
        PulseBeaconRecorder.shared.stamp(.hubApplyTap)
        // Fresh install / login: do not invent status 100 — wait for `suphome`.
        guard let snap = snapshot.value, snap.memberState != nil else {
            if !isBusy.value {
                refreshHub(evaluateAutoOrder: true)
            }
            return
        }
        if autoOrderPilot.handlePrimaryTap(from: host) {
            return
        }
        performStatusJump(from: host, allowRecommend: true)
    }

    func performStatusJump(from host: UIViewController, allowRecommend: Bool) {
        // Only real `userStatus` from home — never default nil → 100 → recommend.
        guard let state = snapshot.value?.memberState else { return }
        let phase = HubMemberPhase(rawValue: state) ?? .other
        switch phase {
        case .verifyPending:
            openVerifyFlow()
        case .creditReady, .processing, .rejectVolume, .other:
            if allowRecommend {
                openRecommend.accept(false)
            }
        case .overdue:
            openOrdersTab.accept(.pendingRepay)
        case .reborrowReady, .withdrawPending, .orderPending:
            openOrdersTab.accept(.submit)
        }
        _ = host
    }

    /// Home message strip tap — order-list / KYC / 据量 (not Apply / recommend).
    func routeStatusMessage(from host: UIViewController) {
        guard let state = snapshot.value?.memberState else { return }
        guard Self.canJumpStatusMessage(state) else { return }
        PulseBeaconRecorder.shared.stamp(.hubApplyTap)
        switch state {
        case HubMemberPhase.verifyPending.rawValue:
            openVerifyFlow()
        case HubMemberPhase.orderPending.rawValue,
             HubMemberPhase.withdrawPending.rawValue,
             HubMemberPhase.reborrowReady.rawValue,
             31:
            // 待抓取 / 拒绝 / 待提现 / 待改卡 → Submit Application 列表 (filter 10).
            openOrdersTab.accept(.submit)
        case HubMemberPhase.processing.rawValue,
             HubMemberPhase.overdue.rawValue:
            // 待还款 / 逾期 → Pending Repayment 列表 (filter 20).
            openOrdersTab.accept(.pendingRepay)
        case HubMemberPhase.rejectVolume.rawValue:
            guard FlexRejectVolumeLaunch.hasURL else { return }
            FlexRejectVolumeLaunch.open(from: host)
        default:
            break
        }
    }

    private func openVerifyFlow() {
        store.loadVerifyStages()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] stages in
                self?.needsVerify.accept(stages)
            }, onError: { [weak self] error in
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func applyMemberPhase(_ snap: HubSnapshotShard) {
        let state = snap.memberState ?? 0
        let phase = HubMemberPhase(rawValue: state) ?? .other
        // Message area stays visible for every status (was wrongly limited to status 10).
        showKycBanner.accept(true)
        statusBannerText.accept(resolvedBannerCopy(snap, fallback: phase.bannerMessage))
        statusBannerTappable.accept(Self.canJumpStatusMessage(state))
        bannerButtonTitle.accept(phase.bannerButtonTitle)
        bannerButtonOverdue.accept(phase.overdueTint)
        quotaAmountText.accept(HubBannerVisual.amountText(snap.quotaAmount))
        rateText.accept(HubBannerVisual.rateText(snap.dailyRate))
        termText.accept(HubBannerVisual.termText(snap.maxTermDays))
    }

    /// Prefer non-empty API message copy; fall back to local status differentiation.
    private func resolvedBannerCopy(_ snap: HubSnapshotShard, fallback: String) -> String {
        let promo = (snap.promoCopy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return promo.isEmpty ? fallback : promo
    }

    /// Home copy tappable — LoanEase: 10/30/31/32/41/80/81；51 仅当有 `rejectH5`；20·100 不可点。
    private static func canJumpStatusMessage(_ userStatus: Int) -> Bool {
        if userStatus == HubMemberPhase.rejectVolume.rawValue {
            return FlexRejectVolumeLaunch.hasURL
        }
        switch userStatus {
        case HubMemberPhase.verifyPending.rawValue,
             HubMemberPhase.orderPending.rawValue,
             31,
             HubMemberPhase.withdrawPending.rawValue,
             HubMemberPhase.reborrowReady.rawValue,
             HubMemberPhase.processing.rawValue,
             HubMemberPhase.overdue.rawValue:
            return true
        default:
            return false
        }
    }

}

extension Notification.Name {
    static let flexHubOpenDealDetail = Notification.Name("flex.hub.openDealDetail")
    static let flexHubNeedsRefresh = Notification.Name("flex.hub.needsRefresh")
    static let flexOpenLedgerTab = Notification.Name("flex.hub.openLedgerTab")
}
