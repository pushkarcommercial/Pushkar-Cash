import Foundation
import ObjectMapper
import RxSwift

final class LedgerOrderStore {
    static let shared = LedgerOrderStore()
    private let wire = PulseWireHub.shared
    private init() {}

    func fetchRows(filter: Int) -> Single<[LedgerRowShard]> {
        wire.dispatch(.ledgerRows(payload: ["orderStatus": "\(filter)"]), as: LedgerRowsEnvelope.self)
            .map { $0.rows }
    }

    func fetchDetail(dealId: String, productId: String) -> Single<LedgerDetailShard> {
        let resolvedOrderId = dealId.isEmpty ? "1" : dealId
        var payload: [String: Any] = [
            "orderId": resolvedOrderId,
            "appType": "DC"
        ]
        if dealId.isEmpty, !productId.isEmpty {
            payload["productId"] = productId
        }
        return wire.dispatch(.ledgerDetail(payload: payload), as: LedgerDetailEnvelope.self)
            .map { $0.shard ?? LedgerDetailShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    func requestWithdraw(dealId: String, loanAmount: String, loanTerm: String) -> Single<Void> {
        wire.dispatchVoid(.ledgerWithdraw(payload: [
            "orderId": dealId,
            "loanAmount": loanAmount,
            "loanTerm": loanTerm
        ]))
    }

    func fetchWithdrawDetail(dealId: String, productId: String) -> Single<LedgerWithdrawProductShard> {
        var payload: [String: Any] = ["orderId": dealId]
        if dealId.isEmpty { payload["productId"] = productId }
        return wire.dispatch(.ledgerWithdrawInfo(payload: payload), as: LedgerWithdrawInfoEnvelope.self)
            .map { $0.shard ?? LedgerWithdrawProductShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    func requestExtend(dealId: String, payAccountNumber: String? = nil) -> Single<RepayLinkShard> {
        var payload: [String: Any] = [
            "orderId": dealId,
            "periodNoList": [1]
        ]
        if let account = Self.normalizedPayAccount(payAccountNumber) {
            payload["payAccountNumber"] = account
        }
        return wire.dispatch(.ledgerExtend(payload: payload), as: RepayLinkEnvelope.self)
            .map { $0.shard ?? RepayLinkShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    func fetchRepayLink(dealId: String, payAccountNumber: String? = nil) -> Single<RepayLinkShard> {
        var payload: [String: Any] = [
            "orderId": dealId,
            "periodNoList": [1]
        ]
        if let account = Self.normalizedPayAccount(payAccountNumber) {
            payload["payAccountNumber"] = account
        }
        return wire.dispatch(.ledgerRepayLink(payload: payload), as: RepayLinkEnvelope.self)
            .map { $0.shard ?? RepayLinkShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    private static func normalizedPayAccount(_ raw: String?) -> String? {
        let trimmed = (raw ?? "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
