import Foundation

/// One product card on the post-submit Loan details (success) screen.
struct FlexLoanSuccessItem {
    let productId: String
    let productTitle: String
    let logoURL: String?
    let loanAmount: String
    let rows: [LedgerDetailRowModel]
    /// Fixed under-review for freshly submitted applications.
    let statusCode: Int

    init(productId: String,
         productTitle: String,
         logoURL: String?,
         loanAmount: String,
         rows: [LedgerDetailRowModel],
         statusCode: Int = 30) {
        self.productId = productId
        self.productTitle = productTitle
        self.logoURL = logoURL
        self.loanAmount = loanAmount
        self.rows = rows
        self.statusCode = statusCode
    }
}

enum FlexLoanSuccessBlueprint {
    static func items(from lines: [FlexRecommendLine]) -> [FlexLoanSuccessItem] {
        lines.compactMap { item(from: $0) }
    }

    static func items(from cards: [OfferCardShard]) -> [FlexLoanSuccessItem] {
        items(from: cards.map { FlexRecommendLine(card: $0) })
    }

    static func item(from line: FlexRecommendLine) -> FlexLoanSuccessItem? {
        guard !line.productId.isEmpty else { return nil }
        return item(productId: line.productId,
                    title: line.title.isEmpty ? "Product" : line.title,
                    logoURL: line.logoURL,
                    loanAmount: line.loanAmount,
                    term: line.currentTerm)
    }

    static func item(productId: String,
                     title: String,
                     logoURL: String?,
                     loanAmount: String,
                     term: OfferTermRowShard?) -> FlexLoanSuccessItem {
        FlexLoanSuccessItem(
            productId: productId,
            productTitle: title,
            logoURL: logoURL,
            loanAmount: loanAmount,
            rows: rows(from: term)
        )
    }

    /// Build success card from `/order/detailV2`.
    static func item(from shard: LedgerDetailShard) -> FlexLoanSuccessItem {
        var models: [LedgerDetailRowModel] = []
        if let days = shard.showTerm {
            models.append(.init(label: FlexPhraseBook.Loan.loanTerm, value: "\(days) (Days)"))
        }
        appendMoney(&models, FlexPhraseBook.Loan.amountReceived,
                    shard.arrivalAmount ?? shard.receiptAmount, hint: .amountReceived)
        appendMoney(&models, FlexPhraseBook.Loan.serviceFee, shard.feeAmount, hint: .serviceFee)
        if shard.interestAmount != "0", !(shard.interestAmount ?? "").isEmpty {
            appendMoney(&models, FlexPhraseBook.Loan.interest, shard.interestAmount, hint: .interest)
        }
        appendMoney(&models, FlexPhraseBook.Loan.gst, shard.taxAmount, hint: nil)
        if let apply = shard.applyStamp, !apply.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.applyDate, value: apply))
        }
        let hasEMI = !(shard.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        if hasEMI {
            if let stamp = shard.emiRepayStamp, !stamp.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiDate, value: stamp))
            }
            if let amount = shard.emiAmount, !amount.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiAmount,
                                    value: RupeeAmountFormat.rupee(amount)))
            }
            if let emis = shard.emis?.trimmingCharacters(in: .whitespacesAndNewlines), !emis.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emis,
                                    value: RupeeAmountFormat.indian(emis)))
            }
        } else if let due = shard.dueStamp, !due.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.dueDate, value: due))
        }
        return FlexLoanSuccessItem(
            productId: shard.productId ?? "",
            productTitle: shard.productTitle ?? "",
            logoURL: shard.productLogo,
            loanAmount: shard.principal ?? "",
            rows: models,
            statusCode: shard.dealState ?? 30
        )
    }

    /// Field order matches apply Loan-details sheet / success mockup.
    static func rows(from term: OfferTermRowShard?) -> [LedgerDetailRowModel] {
        guard let term else { return [] }
        var models: [LedgerDetailRowModel] = []
        let days = term.showTerm ?? term.loanTerm ?? 0
        models.append(.init(
            label: FlexPhraseBook.Loan.loanTerm,
            value: "\(days) (Days)"
        ))
        appendMoney(&models, FlexPhraseBook.Loan.amountReceived,
                    term.arrivalAmount ?? term.receiptAmount, hint: .amountReceived)
        appendMoney(&models, FlexPhraseBook.Loan.serviceFee, term.feeAmount, hint: .serviceFee)
        if term.interestAmount != "0", !(term.interestAmount ?? "").isEmpty {
            appendMoney(&models, FlexPhraseBook.Loan.interest, term.interestAmount, hint: .interest)
        }
        appendMoney(&models, FlexPhraseBook.Loan.gst, term.taxAmount, hint: nil)
        if let apply = term.applyStamp, !apply.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.applyDate, value: apply))
        }
        if term.hasEMI {
            if let stamp = term.emiRepayStamp, !stamp.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiDate, value: stamp))
            }
            if let amount = term.emiAmount, !amount.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emiAmount,
                                    value: RupeeAmountFormat.rupee(amount)))
            }
            let emis = term.emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !emis.isEmpty {
                models.append(.init(label: FlexPhraseBook.Loan.emis,
                                    value: RupeeAmountFormat.indian(emis)))
            }
        } else if let due = term.dueStamp, !due.isEmpty {
            models.append(.init(label: FlexPhraseBook.Loan.dueDate, value: due))
        }
        return models
    }

    private static func appendMoney(_ rows: inout [LedgerDetailRowModel],
                                    _ label: String,
                                    _ raw: String?,
                                    hint: FlexFieldHintKind?) {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        rows.append(.init(label: label, value: RupeeAmountFormat.indian(raw), hintKind: hint))
    }
}
