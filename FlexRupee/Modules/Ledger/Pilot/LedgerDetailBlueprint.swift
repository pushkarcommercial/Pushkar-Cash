import UIKit

enum LedgerStatusLexicon {
    /// List filter 20 / detail 60 / alias 63 — all “awaiting repayment”.
    static let repaymentDueCodes: Set<Int> = [20, 60, 63]
    static let overdueCodes: Set<Int> = [61]
    static let paidOffCodes: Set<Int> = [40, 70, 71]

    static func label(for code: Int) -> String {
        switch code {
        case 10: return "Unfinished Application"
        case 30: return "Under review"
        case 31, 41: return "Reject"
        case 32: return "To be withdrawn"
        case 36: return "Change bank account"
        case 50: return "Loan processing"
        case 20, 60, 63: return "Pending Repayment"
        case 61: return "Overdue"
        case 40, 70, 71: return "Pay off"
        case 99: return "Cancel"
        default: return "Processing"
        }
    }

    static func tint(for code: Int) -> UIColor {
        switch code {
        case 10: return UIColor(hex: 0xF5A623)
        case 30: return UIColor(hex: 0x4A7FD4)
        case 32: return FlexPalette.accentGreen
        case 50: return FlexPalette.primaryTeal
        case 36: return UIColor(hex: 0x8B6FD4)
        case 20, 60, 63: return FlexPalette.dangerRose
        case 61: return UIColor(hex: 0xA67C52)
        case 40, 70, 71: return FlexPalette.accentGreen
        case 31, 41, 99: return FlexPalette.inkSecondary
        default: return FlexPalette.inkSecondary
        }
    }

    static func ringTint(for code: Int) -> UIColor {
        switch code {
        case 32: return FlexPalette.primaryTeal
        default: return tint(for: code)
        }
    }
}

struct LedgerDetailRowModel {
    let label: String
    let value: String
    let hintKind: FlexFieldHintKind?
    let selectKind: LedgerWithdrawSelectKind?

    init(label: String, value: String, hintKind: FlexFieldHintKind? = nil, selectKind: LedgerWithdrawSelectKind? = nil) {
        self.label = label
        self.value = value
        self.hintKind = hintKind
        self.selectKind = selectKind
    }
}

enum LedgerWithdrawSelectKind {
    case amount
    case term
}

struct LedgerWithdrawSelection {
    let product: LedgerWithdrawProductShard
    let tierIndex: Int
    let termIndex: Int

    var tier: LedgerWithdrawAmountShard? {
        guard tierIndex >= 0, tierIndex < product.amountTiers.count else { return nil }
        return product.amountTiers[tierIndex]
    }

    var term: LedgerWithdrawTermShard? {
        guard let tier, termIndex >= 0, termIndex < tier.termOptions.count else { return nil }
        return tier.termOptions[termIndex]
    }

    var loanAmount: String {
        tier?.principal ?? product.principal ?? ""
    }

    var loanTerm: String {
        if let loanTerm = term?.loanTerm { return "\(loanTerm)" }
        if let showTerm = term?.showTerm { return "\(showTerm)" }
        return ""
    }
}

enum LedgerDetailAction {
    case none
    case withdraw
    case repay
    case repayAndDefer
    case continueSubmit
    case changeBank
}

struct LedgerDetailPresentation {
    let bannerHint: String?
    let footerNote: String?
    let statusCode: Int
    let productTitle: String
    let productLogoURL: String?
    let principal: String?
    let rows: [LedgerDetailRowModel]
    let bankMask: String?
    let showsBankBar: Bool
    let showsUPIWarning: Bool
    let action: LedgerDetailAction
    let amountSelectable: Bool
}

// MARK: - Blueprint

enum LedgerDetailBlueprint {
    /// - Parameter withdrawAvailable: when `false` and status is 32, hide Withdraw CTA
    ///   (withdraw detail fetch failed / empty).
    static func fromDetail(_ shard: LedgerDetailShard, withdrawAvailable: Bool = true) -> LedgerDetailPresentation {
        let state = shard.dealState ?? 0
        let facts = LedgerDetailFacts(shard: shard)
        var resolvedAction = action(for: state, canExtend: shard.canExtend)
        if state == 32, !withdrawAvailable {
            resolvedAction = .none
        }
        return LedgerDetailPresentation(
            bannerHint: bannerHint(for: state),
            footerNote: footerNote(for: state, shard: shard),
            statusCode: state,
            productTitle: shard.productTitle ?? "",
            productLogoURL: shard.productLogo,
            principal: shard.principal,
            rows: LedgerDetailFieldComposer.rows(status: state, facts: facts),
            bankMask: shard.bankMask,
            showsBankBar: showsBankBar(for: state, bankMask: shard.bankMask),
            showsUPIWarning: LedgerStatusLexicon.repaymentDueCodes.contains(state)
                || LedgerStatusLexicon.overdueCodes.contains(state),
            action: resolvedAction,
            amountSelectable: false
        )
    }

    /// Post-submit success: summary rows; EMI plan replaces due date when present.
    static func fromSuccess(_ shard: LedgerDetailShard) -> LedgerDetailPresentation {
        let state = shard.dealState ?? 30
        let facts = LedgerDetailFacts(shard: shard)
        var keys: [LedgerDetailFieldKey] = [
            .loanTerm, .amountReceived, .interest, .serviceFee, .gst, .applyDate
        ]
        if facts.hasEmiPlan {
            if facts.hasEmiDate { keys.append(.emiDate) }
            if facts.hasEmiAmount { keys.append(.emiAmount) }
            keys.append(.emis)
        } else {
            keys.append(.dueDate)
        }
        let rows = keys.map { key in
            LedgerDetailRowModel(label: key.title, value: facts.displayValue(for: key), hintKind: key.hintKind)
        }
        return LedgerDetailPresentation(
            bannerHint: nil,
            footerNote: nil,
            statusCode: state,
            productTitle: shard.productTitle ?? "",
            productLogoURL: shard.productLogo,
            principal: shard.principal,
            rows: rows,
            bankMask: nil,
            showsBankBar: false,
            showsUPIWarning: false,
            action: .none,
            amountSelectable: false
        )
    }

    static func fromWithdraw(_ selection: LedgerWithdrawSelection) -> LedgerDetailPresentation {
        let product = selection.product
        let facts = LedgerDetailFacts(withdrawTerm: selection.term)
        let termSelectable = (selection.tier?.termOptions.count ?? 0) > 1
        var rows = LedgerDetailFieldComposer.rows(status: 32, facts: facts)
        if termSelectable {
            rows = rows.map { row in
                guard row.label == LedgerDetailFieldKey.loanTerm.title else { return row }
                return LedgerDetailRowModel(label: row.label, value: row.value,
                                           hintKind: row.hintKind, selectKind: .term)
            }
        }
        return LedgerDetailPresentation(
            bannerHint: FlexPhraseBook.Ledger.bannerWithdraw,
            footerNote: nil,
            statusCode: 32,
            productTitle: product.productTitle ?? "",
            productLogoURL: product.productLogo,
            principal: selection.loanAmount,
            rows: rows,
            bankMask: product.bankMask,
            showsBankBar: showsBankBar(for: 32, bankMask: product.bankMask),
            showsUPIWarning: false,
            action: .withdraw,
            amountSelectable: product.amountTiers.count > 1
        )
    }

    static func fromWithdraw(_ product: LedgerWithdrawProductShard) -> LedgerDetailPresentation {
        let tierIndex = max(0, product.amountTiers.count - 1)
        let termCount = product.amountTiers.indices.contains(tierIndex)
            ? product.amountTiers[tierIndex].termOptions.count
            : 1
        let termIndex = max(0, termCount - 1)
        return fromWithdraw(LedgerWithdrawSelection(product: product, tierIndex: tierIndex, termIndex: termIndex))
    }

    private static func bannerHint(for state: Int) -> String? {
        switch state {
        case 30: return FlexPhraseBook.Ledger.bannerReview
        case 32: return FlexPhraseBook.Ledger.bannerWithdraw
        case 20, 60: return FlexPhraseBook.Ledger.bannerRepay
        case 63: return FlexPhraseBook.Ledger.noteRepayAlt
        case 61: return FlexPhraseBook.Ledger.noteOverdue
        default: return nil
        }
    }

    private static func footerNote(for state: Int, shard: LedgerDetailShard? = nil) -> String? {
        if bannerHint(for: state) != nil { return nil }
        switch state {
        case 10: return FlexPhraseBook.Ledger.noteContinueSubmit
        case 30: return FlexPhraseBook.Ledger.noteReview
        case 31, 41:
            let next = resolvedNextApplyDate(from: shard)
            return FlexPhraseBook.Ledger.noteReject(nextApplyDate: next)
        case 50: return FlexPhraseBook.Ledger.noteDisbursing
        case 20, 60: return FlexPhraseBook.Ledger.noteRepay
        case 63: return FlexPhraseBook.Ledger.noteRepayAlt
        case 61: return FlexPhraseBook.Ledger.noteOverdue
        case 36: return FlexPhraseBook.Ledger.noteChangeBank
        case 70: return FlexPhraseBook.Ledger.notePaidOff
        case 40, 71: return FlexPhraseBook.Ledger.notePaidOffHigher
        case 99: return FlexPhraseBook.Ledger.noteCancel
        default: return nil
        }
    }

    /// LoanEase: prefer `nextApplyDate`, else apply/risk date + 30 days, else today + 30.
    private static func resolvedNextApplyDate(from shard: LedgerDetailShard?) -> String {
        if let next = shard?.nextApplyDate?.trimmingCharacters(in: .whitespacesAndNewlines), !next.isEmpty {
            return next
        }
        let candidates = [shard?.riskStamp, shard?.applyStamp]
        for raw in candidates {
            if let date = parseOrderDate(raw) {
                let next = Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date
                return formatOrderDate(next)
            }
        }
        let next = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return formatOrderDate(next)
    }

    private static func parseOrderDate(_ raw: String?) -> Date? {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        let formats = [
            "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd", "yyyy/MM/dd HH:mm:ss",
            "dd-MM-yyyy", "dd/MM/yyyy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func formatOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func action(for state: Int, canExtend: String?) -> LedgerDetailAction {
        switch state {
        case 10: return .continueSubmit
        case 32: return .withdraw
        case 36: return .changeBank
        case 61:
            // LoanEase overdue: Repay only — Defer is not offered.
            return .repay
        case 20, 60, 63:
            return isExtensionEnabled(canExtend) ? .repayAndDefer : .repay
        default:
            return .none
        }
    }

    private static func isExtensionEnabled(_ raw: String?) -> Bool {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return trimmed == "1" || trimmed == "true" || trimmed == "y" || trimmed == "yes"
    }

    private static func showsBankBar(for state: Int, bankMask: String?) -> Bool {
        let mask = bankMask?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !mask.isEmpty else { return false }
        switch state {
        case 31, 41, 40, 70, 71, 99: return false
        default: return true
        }
    }
}

// MARK: - Field keys & composer (order-detail only)

private enum LedgerDetailFieldKey: CaseIterable {
    case emis, emiDate, emiAmount
    case loanTerm, amountReceived, interest, serviceFee, gst
    case applyDate, paymentDate, lateCharge
    case totalRepayment, deduction, repaid, amountDue, dueDate, repaymentDate

    var title: String {
        switch self {
        case .emis: return "EMIs"
        case .emiDate: return "1st EMI Date"
        case .emiAmount: return "EMI Amount"
        case .loanTerm: return "Loan term"
        case .amountReceived: return "Amount received"
        case .interest: return "Interest"
        case .serviceFee: return "Service fee"
        case .gst: return "GST"
        case .applyDate: return FlexPhraseBook.Ledger.applyDate
        case .paymentDate: return FlexPhraseBook.Ledger.paymentDate
        case .lateCharge: return "Late charge"
        case .totalRepayment: return "Total repayment"
        case .deduction: return "Amount of deduction"
        case .repaid: return "Amount repaid"
        case .amountDue: return "Amount due"
        case .dueDate: return FlexPhraseBook.Ledger.dueDate
        case .repaymentDate: return FlexPhraseBook.Ledger.repaymentDate
        }
    }

    var hintKind: FlexFieldHintKind? {
        switch self {
        case .amountReceived: return .amountReceived
        case .interest: return .interest
        case .serviceFee: return .serviceFee
        default: return nil
        }
    }
}

/// Builds the visible field list for order detail from status + payload facts.
private enum LedgerDetailFieldComposer {
    static func rows(status: Int, facts: LedgerDetailFacts) -> [LedgerDetailRowModel] {
        template(for: status)
            .filter { isVisible($0, facts: facts) }
            .map { key in
                LedgerDetailRowModel(
                    label: key.title,
                    value: facts.displayValue(for: key),
                    hintKind: key.hintKind
                )
            }
    }

    /// Status → candidate fields (EMI block first when present).
    private static func template(for status: Int) -> [LedgerDetailFieldKey] {
        let emiHead: [LedgerDetailFieldKey] = [.emis, .emiDate, .emiAmount]
        let core: [LedgerDetailFieldKey] = [.loanTerm, .amountReceived, .interest, .serviceFee, .gst]
        let repayTail: [LedgerDetailFieldKey] = [
            .applyDate, .paymentDate, .totalRepayment, .deduction, .repaid, .amountDue, .dueDate
        ]
        // Overdue: 放款时间 (paymentDate) + late charge + due date.
        let overdueTail: [LedgerDetailFieldKey] = [
            .applyDate, .paymentDate, .lateCharge, .totalRepayment, .deduction, .repaid, .amountDue, .dueDate
        ]
        // Settled: 放款时间 + … + 结清日期 (repaymentDate); no apply date (LoanEase).
        let paidTail: [LedgerDetailFieldKey] = [
            .paymentDate, .totalRepayment, .deduction, .repaid, .amountDue, .dueDate, .repaymentDate
        ]

        if LedgerStatusLexicon.repaymentDueCodes.contains(status) {
            return emiHead + core + repayTail
        }
        if LedgerStatusLexicon.overdueCodes.contains(status) {
            return emiHead + core + overdueTail
        }
        if LedgerStatusLexicon.paidOffCodes.contains(status) {
            return emiHead + core + paidTail
        }
        switch status {
        case 10, 30, 31, 32, 36, 50, 99:
            return emiHead + core + [.applyDate, .dueDate]
        default:
            return emiHead + core + [.applyDate, .dueDate]
        }
    }

    private static func isVisible(_ key: LedgerDetailFieldKey, facts: LedgerDetailFacts) -> Bool {
        switch key {
        case .emis:
            return facts.hasEmiPlan
        case .emiDate:
            return facts.hasEmiDate
        case .emiAmount:
            return facts.hasEmiAmount
        case .interest:
            return facts.hasInterest
        case .amountReceived:
            return facts.hasAmountReceived
        case .serviceFee:
            return facts.hasServiceFee
        case .gst:
            return facts.hasGST
        case .lateCharge:
            return facts.hasLateCharge
        case .totalRepayment:
            return facts.hasTotalRepayment
        case .paymentDate:
            return facts.hasDisbursementDate
        case .applyDate:
            // Application date and disbursement date are mutually exclusive.
            return !facts.hasDisbursementDate
        case .repaymentDate:
            return facts.hasSettlementDate
        case .deduction:
            return facts.hasDeduction
        case .repaid:
            return facts.hasRepaid
        case .amountDue:
            // First-time repayers often have neither deduction nor prior repaid — still show due.
            return facts.hasAmountDue
        default:
            return true
        }
    }
}

// MARK: - Facts from API payloads

private struct LedgerDetailFacts {
    private let termDays: Int?
    private let receipt: String?
    private let interest: String?
    private let fee: String?
    private let tax: String?
    private let apply: String?
    /// 放款时间 ← `payoutDate` only (do not mix with 结清日).
    private let payout: String?
    /// 结清日期 ← `repaymentDate`.
    private let settled: String?
    private let penalty: String?
    private let totalRepay: String?
    private let reduction: String?
    private let alreadyPaid: String?
    private let shouldPay: String?
    private let due: String?
    private let emiCount: String?
    private let emiDate: String?
    private let emiAmount: String?

    init(shard: LedgerDetailShard) {
        termDays = shard.showTerm
        receipt = shard.arrivalAmount ?? shard.receiptAmount
        interest = shard.interestAmount
        fee = shard.feeAmount
        tax = shard.taxAmount
        apply = shard.applyStamp
        payout = shard.payoutStamp
        settled = shard.repayStamp
        penalty = shard.penaltyAmount
        totalRepay = shard.totalRepaymentAmount
        reduction = shard.reductionAmount
        alreadyPaid = shard.alreadyRepaymentAmount
        shouldPay = shard.shouldRepaymentAmount
        due = shard.dueStamp
        emiCount = shard.emis
        emiDate = shard.emiRepayStamp
        emiAmount = shard.emiAmount
    }

    init(withdrawTerm term: LedgerWithdrawTermShard?) {
        termDays = term?.showTerm ?? term?.loanTerm
        receipt = term?.arrivalAmount ?? term?.receiptAmount
        interest = term?.interestAmount
        fee = term?.feeAmount
        tax = term?.taxAmount
        apply = term?.applyStamp
        payout = nil
        settled = nil
        penalty = nil
        totalRepay = nil
        reduction = nil
        alreadyPaid = nil
        shouldPay = nil
        due = term?.dueStamp
        emiCount = term?.emis
        emiDate = term?.emiRepayStamp
        emiAmount = term?.emiAmount
    }

    var hasInterest: Bool { !isBlankOrZero(interest) }
    var hasAmountReceived: Bool { !isBlank(receipt) }
    var hasServiceFee: Bool { !isBlank(fee) }
    var hasGST: Bool { !isBlank(tax) }
    var hasLateCharge: Bool { !isBlankOrZero(penalty) }
    var hasTotalRepayment: Bool { !isBlank(totalRepay) }
    var hasDisbursementDate: Bool { !isBlank(payout) }
    var hasSettlementDate: Bool { !isBlank(settled) }
    var hasDeduction: Bool { !isBlankOrZero(reduction) }
    var hasRepaid: Bool { !isBlankOrZero(alreadyPaid) }
    var hasAmountDue: Bool { !isBlank(shouldPay) }
    /// Match apply / success — EMI block appears when installment count is present.
    var hasEmiPlan: Bool { !isBlank(emiCount) }
    var hasEmiDate: Bool { hasEmiPlan && !isBlank(emiDate) }
    var hasEmiAmount: Bool { hasEmiPlan && !isBlank(emiAmount) }

    func displayValue(for key: LedgerDetailFieldKey) -> String {
        switch key {
        case .loanTerm:
            guard let termDays else { return "-" }
            return "\(termDays) (Days)"
        case .amountReceived: return money(receipt)
        case .interest: return money(interest)
        case .serviceFee: return money(fee)
        case .gst: return money(tax)
        case .applyDate: return text(apply)
        case .paymentDate: return text(payout)
        case .lateCharge: return money(penalty)
        case .totalRepayment: return money(totalRepay)
        case .deduction: return money(reduction)
        case .repaid: return money(alreadyPaid)
        case .amountDue: return money(shouldPay)
        case .dueDate: return text(due)
        case .repaymentDate: return text(settled)
        case .emiDate: return text(emiDate)
        case .emiAmount:
            guard let raw = emiAmount?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "-" }
            return RupeeAmountFormat.rupee(raw)
        case .emis:
            guard let raw = emiCount?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "-" }
            return RupeeAmountFormat.indian(raw)
        }
    }
}

private func money(_ raw: String?) -> String {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "-" }
    return RupeeAmountFormat.rupee(raw)
}

private func text(_ raw: String?) -> String {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "-" : trimmed
}

private func firstNonBlank(_ values: String?...) -> String? {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
    }
    return nil
}

private func isBlank(_ raw: String?) -> Bool {
    (raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
}

private func isBlankOrZero(_ raw: String?) -> Bool {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else { return true }
    if trimmed == "0" || trimmed == "0.0" || trimmed == "0.00" { return true }
    if let number = Double(trimmed.filter { $0.isNumber || $0 == "." || $0 == "-" }), number == 0 {
        return true
    }
    return false
}
