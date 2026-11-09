import Foundation
import RxSwift

final class FlexLoanPilot {
    let bundle = FlexRelay<OfferTermBundleShard?>(nil)
    let selectedAmount = FlexRelay("")
    let selectedTermIndex = FlexRelay(0)
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()
    let orderTipSignal = FlexSignal<(message: String, dealId: String?, code: Int)>()

    private let hubStore = MintHubStore.shared
    private let disposeBag = DisposeBag()
    private var requestedProductId = ""
    private var floorAmount = 1000
    private var ceilingAmount = 50000
    private var selectedTierIndex = 0

    var hasMultipleAmountTiers: Bool {
        (bundle.value?.tiers.count ?? 0) > 1
    }

    /// Hide − when already on the lowest selectable amount.
    var canDecreaseAmount: Bool {
        guard hasMultipleAmountTiers else { return false }
        return selectedTierIndex > 0
    }

    /// Hide + when already on the highest selectable amount.
    var canIncreaseAmount: Bool {
        guard hasMultipleAmountTiers else { return false }
        return selectedTierIndex < (bundle.value?.tiers.count ?? 0) - 1
    }

    func load(productId: String) {
        requestedProductId = productId
        isBusy.accept(true)
        hubStore.loadOfferTermBundle(productId: productId)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] termBundle in
                guard let self else { return }
                self.bundle.accept(termBundle)
                self.floorAmount = Int(termBundle.floorAmount ?? "1000") ?? 1000
                self.ceilingAmount = Int(termBundle.ceilingAmount ?? "50000") ?? 50000
                if termBundle.tiers.count > 1 {
                    self.selectedTierIndex = max(0, termBundle.tiers.count - 1)
                    let amount = termBundle.tiers[self.selectedTierIndex].loanAmount
                        ?? termBundle.rootAmount
                        ?? termBundle.floorAmount
                        ?? "10000"
                    self.selectedAmount.accept(RupeeAmountFormat.clampLoanValue(amount))
                } else {
                    self.selectedTierIndex = 0
                    let initial = termBundle.rootAmount
                        ?? termBundle.tiers.last?.loanAmount
                        ?? termBundle.floorAmount
                        ?? "10000"
                    self.selectedAmount.accept(RupeeAmountFormat.clampLoanValue(initial))
                }
                // Default to shortest / first term option.
                self.selectedTermIndex.accept(0)
                self.isBusy.accept(false)
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                self?.handleLoadFault(error)
            })
            .disposed(by: disposeBag)
    }

    private func handleLoadFault(_ error: Error) {
        guard case PulseWireFault.business(let code, let message) = error else {
            toastSignal.accept((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            return
        }
        switch code {
        case 6230002, 6230003:
            orderTipSignal.accept((message: message, dealId: nil, code: code))
        default:
            toastSignal.accept(message.isEmpty ? FlexPhraseBook.Network.busy : message)
        }
    }

    func adjustAmount(by delta: Int) {
        guard let bundle = bundle.value, !bundle.tiers.isEmpty else { return }
        if bundle.tiers.count > 1 {
            let step = delta > 0 ? 1 : -1
            let next = min(bundle.tiers.count - 1, max(0, selectedTierIndex + step))
            selectedTierIndex = next
            if let amount = bundle.tiers[next].loanAmount {
                selectedAmount.accept(RupeeAmountFormat.clampLoanValue(amount))
            }
            selectedTermIndex.accept(0)
            return
        }
        let current = Int(selectedAmount.value) ?? floorAmount
        let next = min(ceilingAmount, max(floorAmount, current + delta))
        selectedAmount.accept("\(next)")
        selectedTermIndex.accept(0)
    }

    func currentTier(for amount: String? = nil) -> OfferAmountTierShard? {
        guard let bundle = bundle.value else { return nil }
        if bundle.tiers.count > 1 {
            guard bundle.tiers.indices.contains(selectedTierIndex) else { return bundle.tiers.last }
            return bundle.tiers[selectedTierIndex]
        }
        let target = amount ?? selectedAmount.value
        if let exact = bundle.tiers.first(where: { RupeeAmountFormat.digits(from: $0.loanAmount) == RupeeAmountFormat.digits(from: target) }) {
            return exact
        }
        return bundle.tiers.last
    }

    func currentTerm() -> OfferTermRowShard? {
        guard let tier = currentTier() else { return nil }
        let index = min(max(0, selectedTermIndex.value), max(0, tier.termRows.count - 1))
        guard tier.termRows.indices.contains(index) else { return tier.termRows.last }
        return tier.termRows[index]
    }

    func termOptions() -> [String] {
        currentTier()?.termRows.map { term in
            if term.hasEMI {
                let count = term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return "\(count) EMIs"
            }
            let days = term.showTerm ?? term.loanTerm ?? 0
            return "\(days) Days"
        } ?? []
    }

    func validateBeforeSubmit() -> String? {
        guard bundle.value != nil else {
            return FlexPhraseBook.Loan.productUnavailable
        }
        let digits = RupeeAmountFormat.digits(from: selectedAmount.value)
        guard let amount = Int(digits), amount > 0 else {
            return FlexPhraseBook.Loan.amountOutOfRange
        }
        if !RupeeInputGuard.isAmountWithinRange(value: amount, floor: floorAmount, ceiling: ceilingAmount) {
            return FlexPhraseBook.Loan.amountOutOfRange
        }
        return nil
    }

    func submit() -> MintDealDraft? {
        if let hint = validateBeforeSubmit() {
            toastSignal.accept(hint)
            return nil
        }
        let resolvedProductId = bundle.value?.productId?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? requestedProductId
        guard !resolvedProductId.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Loan.productUnavailable)
            return nil
        }
        let term = currentTerm()
        let loanTerm = term?.loanTerm ?? term?.showTerm ?? 1
        let loanAmount = RupeeAmountFormat.digits(from: selectedAmount.value)
        PulseBeaconRecorder.shared.stamp(.loanConfirmSubmit)
        return MintDealDraft(productId: resolvedProductId, loanAmount: loanAmount, showTerm: "\(loanTerm)")
    }
}
