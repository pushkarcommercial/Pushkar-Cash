import Foundation
import RxSwift

final class FlexRecommendLine {
    let card: OfferCardShard
    var isSelected = true
    var amountIndex = 0
    var termIndex = 0

    init(card: OfferCardShard) {
        self.card = card
        selectHighestQuota()
    }

    var productId: String { card.productId ?? card.termBundle?.productId ?? "" }
    var title: String { card.productTitle ?? card.termBundle?.productTitle ?? "" }
    var logoURL: String? { card.logoURL ?? card.termBundle?.logoURL }
    var tiers: [OfferAmountTierShard] { card.termBundle?.tiers ?? [] }

    var currentTier: OfferAmountTierShard? {
        guard !tiers.isEmpty else { return nil }
        let index = min(max(0, amountIndex), tiers.count - 1)
        return tiers[index]
    }

    var currentTerm: OfferTermRowShard? {
        guard let rows = currentTier?.termRows, !rows.isEmpty else { return nil }
        let index = min(max(0, termIndex), rows.count - 1)
        return rows[index]
    }

    var loanAmount: String {
        RupeeAmountFormat.digits(from: currentTier?.loanAmount ?? currentTerm?.receiptAmount)
    }

    var receivedAmount: String {
        RupeeAmountFormat.digits(from: currentTerm?.arrivalAmount)
    }

    var canStepAmount: Bool { isSelected && tiers.count > 1 }

    var resolvedBankCards: [RecommendBankShard] {
        let nested = card.termBundle?.bankCards ?? []
        if !nested.isEmpty { return nested }
        return card.bankCards
    }

    /// Default: highest loan amount + highest term (auto-order shares this).
    func selectHighestQuota() {
        guard let bundle = card.termBundle, !bundle.tiers.isEmpty else {
            amountIndex = 0
            termIndex = 0
            return
        }
        amountIndex = bundle.highestAmountIndex()
        if let tier = currentTier {
            termIndex = bundle.highestTermIndex(in: tier)
        } else {
            termIndex = 0
        }
    }

    func stepAmount(_ delta: Int) {
        guard tiers.count > 1 else { return }
        amountIndex = min(tiers.count - 1, max(0, amountIndex + delta))
        if let tier = currentTier, let bundle = card.termBundle {
            termIndex = bundle.highestTermIndex(in: tier)
        } else {
            termIndex = 0
        }
    }

    func termOptions() -> [String] {
        (currentTier?.termRows ?? []).map { row in
            let days = row.showTerm ?? row.loanTerm ?? 0
            return "\(days) Days"
        }
    }

    func draft() -> MintDealDraft? {
        guard !productId.isEmpty, !loanAmount.isEmpty else { return nil }
        let days = currentTerm?.loanTerm ?? currentTerm?.showTerm ?? 1
        return MintDealDraft(productId: productId, loanAmount: loanAmount, showTerm: "\(days)")
    }
}

final class FlexRecommendApplyPilot {
    let lines = FlexRelay<[FlexRecommendLine]>([])
    let toastSignal = FlexSignal<String>()
    let reloadSignal = FlexSignal<Void>()
    let isBusy = FlexRelay(false)
    let openSuccess = FlexSignal<[String]>()

    func bind(cards: [OfferCardShard]) {
        let rows = cards.map { FlexRecommendLine(card: $0) }
        rows.forEach { $0.isSelected = true }
        lines.accept(rows)
    }

    var selectedLines: [FlexRecommendLine] {
        lines.value.filter { $0.isSelected }
    }

    func toggleSelect(at index: Int) {
        guard lines.value.indices.contains(index) else { return }
        lines.value[index].isSelected.toggle()
        reloadSignal.accept(())
    }

    func stepAmount(at index: Int, delta: Int) {
        guard lines.value.indices.contains(index) else { return }
        lines.value[index].stepAmount(delta)
        reloadSignal.accept(())
    }

    func setTerm(at index: Int, termIndex: Int) {
        guard lines.value.indices.contains(index) else { return }
        lines.value[index].termIndex = termIndex
        reloadSignal.accept(())
    }

    /// Total fee = total quota − total received (frontend calc).
    func totals() -> (amount: Int, fee: Int, received: Int) {
        let amount = selectedLines.reduce(0) { $0 + (Int($1.loanAmount) ?? 0) }
        let received = selectedLines.reduce(0) { $0 + (Int($1.receivedAmount) ?? 0) }
        return (amount, max(0, amount - received), received)
    }

    func bankMask() -> String {
        let cards = selectedLines.first?.resolvedBankCards
            ?? lines.value.first?.resolvedBankCards
            ?? []
        let raw = cards.first?.accountNo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return "****************" }
        return FlexCofferWidgets.groupedAccountNumber(raw)
    }

    func submit(from host: UIViewController, agreed: Bool) {
        guard agreed else {
            toastSignal.accept(FlexPhraseBook.Loan.agreementRequired)
            return
        }
        let drafts = selectedLines.compactMap { $0.draft() }
        guard !drafts.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Hub.selectOneProduct)
            return
        }
        guard !isBusy.value else { return }
        isBusy.accept(true)
        PulseBeaconRecorder.shared.stamp(.loanConfirmSubmit)
        MintDealPipeline(host: host).execute(drafts: drafts, onSuccess: { [weak self] orderIds in
            self?.isBusy.accept(false)
            // Deliver on main — harvest chain already hops to MainScheduler, keep push safe.
            DispatchQueue.main.async {
                self?.openSuccess.accept(orderIds)
            }
        }, onAbort: { [weak self] in
            self?.isBusy.accept(false)
        })
    }
}

enum FlexRecommendDraftBuilder {
    /// Auto-order / default quota: every product at highest amount + highest term.
    static func highestQuotaDrafts(from cards: [OfferCardShard]) -> [MintDealDraft] {
        cards.compactMap { card in
            let line = FlexRecommendLine(card: card)
            line.isSelected = true
            return line.draft()
        }
    }
}
