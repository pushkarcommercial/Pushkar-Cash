import Foundation
import ObjectMapper

protocol WireShard: Mappable {}

class WireEnvelope: WireShard {
    var pulseCode: Int?
    var serverMessage: String?
    /// Keep local copy as the fallback when the API omits resultMsg.
    var localMessage: String? { FlexPhraseBook.Network.message(for: pulseCode) }
    var businessMessage: String {
        let message = serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return message.isEmpty ? (localMessage ?? FlexPhraseBook.Network.busy) : message
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        pulseCode <- map["resultCode"]
        serverMessage <- map["resultMsg"]
    }

}

class GateTokenEnvelope: WireEnvelope {
    var shard: GateTokenShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class GateTokenShard: WireShard {
    var memberId: String?
    var bearerToken: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        memberId <- map["userId"]
        bearerToken <- map["token"]
    }
}

class MintProfileEnvelope: WireEnvelope {
    var shard: MintProfileShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class MintProfileShard: WireShard {
    var displayName: String?
    var mobileLine: String?
    var bankEditSwitch: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        displayName <- map["name"]
        mobileLine <- map["phone"]
        bankEditSwitch <- map["payAccountModifySwitch"]
    }
}

class HubSnapshotEnvelope: WireEnvelope {
    var shard: HubSnapshotShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class HubSnapshotShard: WireShard {
    var memberState: Int?
    var memberTier: String?
    var hasActiveDeal: Bool?
    var creditLineHint: String?
    var withdrawDealId: String?
    var harvestContactsFlag: Int?
    /// Home message-area copy from `sup/home` (`promptCopy` / obfuscated aliases).
    var promoCopy: String?
    /// Banner amount may come from the quota or selected loan amount.
    var quotaAmount: String?
    /// Daily rate from the product response.
    var dailyRate: String?
    /// Max term days from the product response.
    var maxTermDays: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        memberState <- map["userStatus"]
        memberTier <- map["appUserType"]
        hasActiveDeal <- map["hasOrder"]
        creditLineHint <- map["firstLoanOptionLine"]
        harvestContactsFlag <- map["retrieveMobileContact"]
        dailyRate <- map["lowestLoanInterestRate"]
        withdrawDealId <- map["withdrawalOrderId"]
        if map.mappingType == .fromJSON {
            // Clear `promptCopy` → LoanEase `celebrate` → legacy Flex `plug`.
            promoCopy = MintConfigShard.parseOptionalString(map["promptCopy"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["celebrate"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["plug"].currentValue)
            quotaAmount = MintConfigShard.parseOptionalString(map["highAmount"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["loanAmount"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["amount"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["maxApplyAmount"].currentValue)
            maxTermDays = MintConfigShard.parseOptionalString(map["loanTerm"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["showTerm"].currentValue)
        }
    }

    var prefersSystemAutoPlace: Bool {
        (creditLineHint ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "system"
    }
}

class OfferDeckEnvelope: WireEnvelope {
    var cards: [OfferCardShard] = []
    override func mapping(map: Map) {
        super.mapping(map: map)
        var productInfoList: [OfferCardShard] = []
        productInfoList <- map["data.productInfoList"]
        var amountDetailList: [OfferCardShard] = []
        amountDetailList <- map["data.amountDetailList"]
        var list: [OfferCardShard] = []
        list <- map["data"]
        cards = [productInfoList, amountDetailList, list].first(where: { !$0.isEmpty }) ?? []
    }

    var quotaCards: [OfferCardShard] {
        cards.filter { card in
            guard !((card.productId ?? "").isEmpty) else { return false }
            if !(card.termBundle?.tiers.isEmpty ?? true) { return true }
            return !card.recommendAmount.isEmpty
        }
    }
}

class OfferCardShard: WireShard {
    var dealId: String?
    var productId: String?
    var productTitle: String?
    var logoURL: String?
    var floorAmount: String?
    var ceilingAmount: String?
    var chosenAmount: String?
    var termBundle: OfferTermBundleShard?
    /// Product-level bank cards when not nested under the term bundle.
    var bankCards: [RecommendBankShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        dealId <- map["orderId"]
        productId <- map["productId"]
        productTitle <- map["productName"]
        logoURL <- map["productLogo"]
        floorAmount <- map["lowAmount"]
        ceilingAmount <- map["highAmount"]
        chosenAmount <- map["loanAmount"]
        termBundle <- map["productTermV3Response"]
        bankCards <- map["bankCardList"]
        if map.mappingType == .fromJSON {
            if termBundle?.tiers.isEmpty != false {
                synthesizeAmountTierIfNeeded()
            }
            // Prefer nested term-bundle cards; fall back to product-level cards.
            if let bundle = termBundle, bundle.bankCards.isEmpty, !bankCards.isEmpty {
                bundle.bankCards = bankCards
            }
        }
    }

    private func synthesizeAmountTierIfNeeded() {
        let amount = recommendAmount
        guard !amount.isEmpty else { return }
        let row = OfferTermRowShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
        let tier = OfferAmountTierShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
        tier.loanAmount = amount
        tier.termRows = [row]
        if termBundle == nil {
            termBundle = OfferTermBundleShard(map: Map(mappingType: .fromJSON, JSON: [:]))
        }
        termBundle?.productId = termBundle?.productId ?? productId
        termBundle?.productTitle = termBundle?.productTitle ?? productTitle
        termBundle?.logoURL = termBundle?.logoURL ?? logoURL
        termBundle?.tiers = [tier]
    }

    var recommendAmount: String {
        if let first = termBundle?.tiers.first?.loanAmount {
            let digits = RupeeAmountFormat.digits(from: first)
            if !digits.isEmpty { return digits }
        }
        let chosen = RupeeAmountFormat.digits(from: chosenAmount)
        if !chosen.isEmpty { return chosen }
        let high = RupeeAmountFormat.digits(from: ceilingAmount)
        if !high.isEmpty { return high }
        return RupeeAmountFormat.digits(from: floorAmount)
    }
}

class RecommendBankShard: WireShard {
    var accountNo: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        accountNo <- map["accountNo"]
        if map.mappingType == .fromJSON {
            if accountNo == nil {
                accountNo = MintConfigShard.parseOptionalString(map["accountMask"].currentValue)
            }
        }
    }
}

class OfferTermEnvelope: WireEnvelope {
    var card: OfferCardShard?
    var bundle: OfferTermBundleShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        card <- map["data"]
        bundle <- map["data"]
    }
}

class OfferTermBundleShard: WireShard {
    var productId: String?
    var productTitle: String?
    var logoURL: String?
    var floorAmount: String?
    var ceilingAmount: String?
    var rootAmount: String?
    var tiers: [OfferAmountTierShard] = []
    var bankCards: [RecommendBankShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        productId <- map["productId"]
        productTitle <- map["productName"]
        logoURL <- map["productLogo"]
        floorAmount <- map["lowAmount"]
        ceilingAmount <- map["highAmount"]
        rootAmount <- map["loanAmount"]
        tiers <- map["amountDetailList"]
        bankCards <- map["bankCardList"]
    }

    func highestAmountIndex() -> Int {
        guard !tiers.isEmpty else { return 0 }
        var best = 0
        var bestAmount = Int.min
        for (index, tier) in tiers.enumerated() {
            let amount = Int(RupeeAmountFormat.digits(from: tier.loanAmount)) ?? Int.min
            if amount >= bestAmount {
                bestAmount = amount
                best = index
            }
        }
        return best
    }

    func highestTermIndex(in tier: OfferAmountTierShard) -> Int {
        guard !tier.termRows.isEmpty else { return 0 }
        var best = 0
        var bestDays = Int.min
        for (index, row) in tier.termRows.enumerated() {
            let days = row.showTerm ?? row.loanTerm ?? Int.min
            if days >= bestDays {
                bestDays = days
                best = index
            }
        }
        return best
    }

}

class OfferAmountTierShard: WireShard {
    var loanAmount: String?
    var termRows: [OfferTermRowShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        loanAmount <- map["loanAmount"]
        termRows <- map["termDetailList"]
    }
}

class OfferTermRowShard: WireShard {
    var showTerm: Int?
    var loanTerm: Int?
    var receiptAmount: String?
    var arrivalAmount: String?
    var interestAmount: String?
    var feeAmount: String?
    var taxAmount: String?
    var applyStamp: String?
    var dueStamp: String?
    var emiRepayStamp: String?
    var emiAmount: String?
    var emis: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        showTerm <- map["showTerm"]
        loanTerm <- map["loanTerm"]
        receiptAmount <- map["receiptAmount"]
        arrivalAmount <- map["arrivalAmount"]
        interestAmount <- map["interestAmount"]
        feeAmount <- map["feeAmount"]
        taxAmount <- map["taxAmount"]
        applyStamp <- map["borrowingDate"]
        dueStamp <- map["repaymentDate"]
        emiRepayStamp <- map["EMIRepayDate"]
        emiAmount <- map["EMIAmount"]
        emis <- map["EMIs"]
        // Do not map `repaymentAmount` into receipt — that is total repay, not amount received.
        // Amount received uses `arrivalAmount` (fallback `receiptAmount`) at display sites.
    }

    var hasEMI: Bool {
        let count = emis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !count.isEmpty
    }
}

class MintConfigEnvelope: WireEnvelope {
    var shard: MintConfigShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class MintConfigShard: WireShard {
    var supportEmail: String?
    var siteURL: String?
    /// Kiva `retrieveMobileContact` (JSON may be Int or String).
    var fetchContactsFlag: Int = 0
    /// Feedback prompt setting from app config.
    var feedbackGuidance: Int?
    var spawnedDealId: String?
    /// All order ids from batch submit (`list` / `orderIdList` / …). `spawnedDealId` = first.
    var spawnedDealIds: [String] = []
    var contactBatchSize: String?
    var contactBatchCap: String?
    /// Optional H5 URL for rejected applications.
    var rejectH5URL: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        supportEmail <- map["appEmail"]
        siteURL <- map["officialWebsiteUrl"]
        spawnedDealId <- map["orderId"]
        if map.mappingType == .fromJSON {
            // pushPerCount (clear) → legacy obfuscated aliases.
            contactBatchSize = Self.parseOptionalString(map["pushPerCount"].currentValue)
                ?? Self.parseOptionalString(map["plural"].currentValue)
                ?? Self.parseOptionalString(map["latter"].currentValue)
                ?? Self.parseOptionalString(map["sore"].currentValue)
                ?? Self.parseOptionalString(map["vacuum"].currentValue)
            // pushMaxCount (clear) → legacy obfuscated aliases.
            contactBatchCap = Self.parseOptionalString(map["pushMaxCount"].currentValue)
                ?? Self.parseOptionalString(map["habit"].currentValue)
                ?? Self.parseOptionalString(map["chess"].currentValue)
                ?? Self.parseOptionalString(map["conduct"].currentValue)
                ?? Self.parseOptionalString(map["famine"].currentValue)
            fetchContactsFlag = Self.parseContactFlag(map["retrieveMobileContact"].currentValue)
            feedbackGuidance = Self.parseOptionalInt(map["feedbackGuidance"].currentValue)
                ?? Self.parseOptionalInt(map["dynamicParameter.feedbackGuidance"].currentValue)
            rejectH5URL = Self.parseOptionalString(map["rejectH5"].currentValue)
                ?? Self.parseOptionalString(map["reject_h5"].currentValue)
                ?? Self.parseOptionalString(map["dynamicParameter.rejectH5"].currentValue)
                ?? Self.parseOptionalString(map["dynamicParameter.reject_h5"].currentValue)

            var ids = Self.collectOrderIds(in: map["list"].currentValue)
            if ids.isEmpty { ids = Self.collectOrderIds(in: map["orderList"].currentValue) }
            if ids.isEmpty { ids = Self.collectOrderIds(in: map["camel"].currentValue) }
            if ids.isEmpty { ids = Self.collectOrderIds(in: map["orderIdList"].currentValue) }
            if ids.isEmpty { ids = Self.collectOrderIds(in: map["orderIds"].currentValue) }
            if ids.isEmpty, let current = Self.parseOptionalString(map["currentOrderId"].currentValue) {
                ids = [current]
            }
            if ids.isEmpty, let primary = spawnedDealId?.trimmingCharacters(in: .whitespacesAndNewlines), !primary.isEmpty {
                ids = [primary]
            }
            if ids.isEmpty, let legacy = Self.parseOptionalString(map["billion"].currentValue)
                ?? Self.parseOptionalString(map["substantial"].currentValue) {
                ids = [legacy]
            }
            spawnedDealIds = ids
            if spawnedDealId == nil || spawnedDealId?.isEmpty == true {
                spawnedDealId = ids.first
            }
        }
    }

    /// All non-empty order ids from submit `list` / id array.
    private static func collectOrderIds(in raw: Any?) -> [String] {
        guard let raw else { return [] }
        if let text = parseOptionalString(raw) { return [text] }

        let items: [Any]
        if let list = raw as? [Any] {
            items = list
        } else if let list = raw as? NSArray {
            items = (0..<list.count).map { list[$0] as Any }
        } else {
            return []
        }

        var ids: [String] = []
        var seen = Set<String>()
        for item in items {
            let candidate: String?
            if let text = parseOptionalString(item) {
                candidate = text
            } else if let dict = dictionaryValue(item) {
                candidate = parseOptionalString(dict["orderId"])
                    ?? parseOptionalString(dict["currentOrderId"])
                    ?? parseOptionalString(dict["billion"])
                    ?? parseOptionalString(dict["substantial"])
            } else {
                candidate = nil
            }
            guard let id = candidate, !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            ids.append(id)
        }
        return ids
    }

    private static func dictionaryValue(_ raw: Any) -> [String: Any]? {
        if let dict = raw as? [String: Any] { return dict }
        if let dict = raw as? NSDictionary {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, value) in dict {
                guard let key = key as? String else { continue }
                out[key] = value
            }
            return out
        }
        return nil
    }

    static func parseContactFlag(_ raw: Any?) -> Int {
        parseOptionalInt(raw) ?? 0
    }

    static func parseOptionalInt(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Int(trimmed)
        }
        return nil
    }

    static func parseOptionalString(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        if let value = raw as? Int { return "\(value)" }
        if let value = raw as? Double {
            return value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
        }
        return nil
    }
}

class LedgerRowsEnvelope: WireEnvelope {
    var rows: [LedgerRowShard] = []
    override func mapping(map: Map) {
        super.mapping(map: map)
        rows <- map["data.orderList"]
    }
}

class LedgerRowShard: WireShard {
    var dealId: String?
    var productId: String?
    var productTitle: String?
    var principal: String?
    var applyStamp: String?
    var grantStamp: String?
    var dueStamp: String?
    var repayStamp: String?
    var dealState: Int?
    required init?(map: Map) {}
    func mapping(map: Map) {
        dealId <- map["orderId"]
        productId <- map["productId"]
        productTitle <- map["productName"]
        applyStamp <- map["applyDate"]
        dueStamp <- map["dueDate"]
        if map.mappingType == .fromJSON {
            principal = MintConfigShard.parseOptionalString(map["loanAmount"].currentValue)
            dealState = MintConfigShard.parseOptionalInt(map["orderStatus"].currentValue)
            // 放款日 ← loanDate / payoutDate；结清日 ← repayDate / repaymentDate
            grantStamp = MintConfigShard.parseOptionalString(map["loanDate"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["payoutDate"].currentValue)
            repayStamp = MintConfigShard.parseOptionalString(map["repayDate"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["repaymentDate"].currentValue)
        }
    }
}

class LedgerDetailEnvelope: WireEnvelope {
    var shard: LedgerDetailShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class LedgerDetailShard: WireShard {
    var dealId: String?
    var productId: String?
    var productTitle: String?
    var productLogo: String?
    var principal: String?
    var dealState: Int?
    var showTerm: Int?
    var receiptAmount: String?
    var arrivalAmount: String?
    var interestAmount: String?
    var feeAmount: String?
    var taxAmount: String?
    var applyStamp: String?
    var payoutStamp: String?
    var penaltyAmount: String?
    var totalRepaymentAmount: String?
    var reductionAmount: String?
    var alreadyRepaymentAmount: String?
    var shouldRepaymentAmount: String?
    var dueStamp: String?
    var repayStamp: String?
    var canExtend: String?
    var emiRepayStamp: String?
    var emiAmount: String?
    var emis: String?
    var bankMask: String?
    /// Reject tip — `nextApplyDate` when provided by detailV2.
    var nextApplyDate: String?
    /// Fallback base date for reject re-apply (+30 days), LoanEase `vast` / riskDate.
    var riskStamp: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        applyStamp <- map["orderDetail.applyDate"]
        payoutStamp <- map["orderDetail.payoutDate"]
        dueStamp <- map["orderDetail.dueDate"]
        repayStamp <- map["orderDetail.repaymentDate"]
        emiRepayStamp <- map["orderDetail.EMIRepayDate"]
        bankMask <- map["bankCard.accountNo"]
        if map.mappingType == .fromJSON {
            // Numbers / strings both appear for status, term, amounts, and extension flag.
            dealId = MintConfigShard.parseOptionalString(map["orderDetail.orderId"].currentValue)
            principal = MintConfigShard.parseOptionalString(map["orderDetail.loanAmount"].currentValue)
            dealState = MintConfigShard.parseOptionalInt(map["orderDetail.orderStatus"].currentValue)
            showTerm = MintConfigShard.parseOptionalInt(map["orderDetail.showTerm"].currentValue)
            receiptAmount = MintConfigShard.parseOptionalString(map["orderDetail.receiptAmount"].currentValue)
            arrivalAmount = MintConfigShard.parseOptionalString(map["orderDetail.arrivalAmount"].currentValue)
            interestAmount = MintConfigShard.parseOptionalString(map["orderDetail.interestAmount"].currentValue)
            feeAmount = MintConfigShard.parseOptionalString(map["orderDetail.feeAmount"].currentValue)
            taxAmount = MintConfigShard.parseOptionalString(map["orderDetail.taxAmount"].currentValue)
            penaltyAmount = MintConfigShard.parseOptionalString(map["orderDetail.penaltyAmount"].currentValue)
            totalRepaymentAmount = MintConfigShard.parseOptionalString(map["orderDetail.totalRepaymentAmount"].currentValue)
            reductionAmount = MintConfigShard.parseOptionalString(map["orderDetail.reductionAmount"].currentValue)
            alreadyRepaymentAmount = MintConfigShard.parseOptionalString(map["orderDetail.alreadyRepaymentAmount"].currentValue)
            shouldRepaymentAmount = MintConfigShard.parseOptionalString(map["orderDetail.shouldRepaymentAmount"].currentValue)
            canExtend = MintConfigShard.parseOptionalString(map["orderDetail.ifExtension"].currentValue)
            emiAmount = MintConfigShard.parseOptionalString(map["orderDetail.EMIAmount"].currentValue)
            emis = MintConfigShard.parseOptionalString(map["orderDetail.EMIs"].currentValue)
            nextApplyDate = MintConfigShard.parseOptionalString(map["orderDetail.nextApplyDate"].currentValue)
            riskStamp = MintConfigShard.parseOptionalString(map["orderDetail.riskDate"].currentValue)
            // Header icon and name come from product when available.
            productId = MintConfigShard.parseOptionalString(map["product.productId"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["orderDetail.productId"].currentValue)
            productTitle = MintConfigShard.parseOptionalString(map["product.productName"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["orderDetail.productName"].currentValue)
            productLogo = MintConfigShard.parseOptionalString(map["product.productLogo"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["orderDetail.productLogo"].currentValue)
            if bankMask == nil {
                bankMask = MintConfigShard.parseOptionalString(map["bankCard.accountNo"].currentValue)
            }
        }
    }
}

class LedgerWithdrawInfoEnvelope: WireEnvelope {
    var shard: LedgerWithdrawProductShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class LedgerWithdrawProductShard: WireShard {
    var dealId: String?
    var productId: String?
    var productTitle: String?
    var productLogo: String?
    var principal: String?
    var bankMask: String?
    var amountTiers: [LedgerWithdrawAmountShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        productTitle <- map["productName"]
        productLogo <- map["productLogo"]
        amountTiers <- map["amountDetailList"]
        bankMask <- map["bankCardList.0.accountNo"]
        if map.mappingType == .fromJSON {
            dealId = MintConfigShard.parseOptionalString(map["orderId"].currentValue)
            productId = MintConfigShard.parseOptionalString(map["productId"].currentValue)
            principal = MintConfigShard.parseOptionalString(map["loanAmount"].currentValue)
            if bankMask == nil {
                bankMask = MintConfigShard.parseOptionalString(map["bankCardList.0.accountNo"].currentValue)
            }
        }
    }
}

class LedgerWithdrawAmountShard: WireShard {
    var principal: String?
    var termOptions: [LedgerWithdrawTermShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        termOptions <- map["termDetailList"]
        if map.mappingType == .fromJSON {
            principal = MintConfigShard.parseOptionalString(map["loanAmount"].currentValue)
        }
    }
}

class LedgerWithdrawTermShard: WireShard {
    var loanTerm: Int?
    var showTerm: Int?
    var receiptAmount: String?
    var arrivalAmount: String?
    var interestAmount: String?
    var feeAmount: String?
    var taxAmount: String?
    var applyStamp: String?
    var dueStamp: String?
    var emiRepayStamp: String?
    var emiAmount: String?
    var emis: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        applyStamp <- map["borrowingDate"]
        dueStamp <- map["repaymentDate"]
        emiRepayStamp <- map["EMIRepayDate"]
        if map.mappingType == .fromJSON {
            loanTerm = MintConfigShard.parseOptionalInt(map["loanTerm"].currentValue)
            showTerm = MintConfigShard.parseOptionalInt(map["showTerm"].currentValue)
            receiptAmount = MintConfigShard.parseOptionalString(map["receiptAmount"].currentValue)
            arrivalAmount = MintConfigShard.parseOptionalString(map["arrivalAmount"].currentValue)
            interestAmount = MintConfigShard.parseOptionalString(map["interestAmount"].currentValue)
            feeAmount = MintConfigShard.parseOptionalString(map["feeAmount"].currentValue)
            taxAmount = MintConfigShard.parseOptionalString(map["taxAmount"].currentValue)
            emiAmount = MintConfigShard.parseOptionalString(map["EMIAmount"].currentValue)
            emis = MintConfigShard.parseOptionalString(map["EMIs"].currentValue)
        }
    }
}

class VerifyStageEnvelope: WireEnvelope {
    var stages: [VerifyStageShard] = []
    override func mapping(map: Map) {
        super.mapping(map: map)
        stages <- map["data.kycList"]
    }
}

class VerifyStageShard: WireShard {
    var stageId: String?
    var stageState: Int?
    var stageKind: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        // Route by kycId values: personal / work / tax / …
        stageId <- map["kycId"]
        var typeHint: String?
        typeHint <- map["kycType"]
        let known: Set<String> = [
            "personal", "work", "questionnaire", "liveness",
            "identity", "tax", "pay_account", "urgent_contact"
        ]
        if let id = stageId, known.contains(id) {
            stageKind = id
        } else {
            stageKind = typeHint ?? stageId
        }
        // API returns kycStatus as String "0"/"1" (sometimes Int).
        if let raw = map["kycStatus"].currentValue {
            if let number = raw as? NSNumber {
                stageState = number.intValue
            } else if let text = raw as? String {
                stageState = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } else if let value = raw as? Int {
                stageState = value
            }
        }
    }
}

class VerifyFormEnvelope: WireEnvelope {
    var shard: VerifyFormShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class VerifyFormShard: WireShard {
    var stageId: String?
    var fields: [VerifyFieldShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        stageId <- map["kycId"]
        fields <- map["kycItemList"]
    }
}

class VerifyFieldShard: WireShard {
    var fieldCode: String?
    var fieldLabel: String?
    var fieldKind: Int?
    var itemSort: Int?
    var isRequired = false
    var requiresInput: Bool { isRequired || fieldCode?.lowercased() == "whatsapp" }
    var patternRule: String?
    var options: [VerifyOptionShard] = []
    required init?(map: Map) {}
    func mapping(map: Map) {
        fieldCode <- map["itemCode"]
        fieldLabel <- map["itemName"]
        fieldKind <- map["itemType"]
        itemSort <- map["itemSort"]
        if map.mappingType == .fromJSON {
            isRequired = ["here", "isRequired"].contains { key in
                switch map[key].currentValue {
                case let value as NSNumber:
                    return value.intValue == 1
                case let value as String:
                    return ["1", "true"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                default:
                    return false
                }
            }
        }
        patternRule <- map["regularExpression"]
        options <- map["buttonList"]
    }
}

class VerifyOptionShard: WireShard {
    var optionKey: String?
    var optionLabel: String?
    var optionSort: Int?
    required init?(map: Map) {}
    func mapping(map: Map) {
        optionKey <- map["buttonKey"]
        optionLabel <- map["buttonLabel"]
        optionSort <- map["buttonSort"]
    }
}

class IFSCListEnvelope: WireEnvelope {
    var list: [String] = []
    override func mapping(map: Map) {
        super.mapping(map: map)
        list <- map["data.list"]
        if list.isEmpty {
            list <- map["data"]
        }
    }
}

class VerifyItemCommitEnvelope: WireEnvelope {
    var shard: VerifyItemCommitShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class VerifyItemCommitShard: WireShard {
    var echoMap: VerifyEchoShard?
    required init?(map: Map) {}
    func mapping(map: Map) {
        echoMap <- map["echoMap"]
    }
}

class VerifyEchoShard: WireShard {
    var cardNo: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        cardNo <- map["cardNo"]
    }
}

class VaultCardEnvelope: WireEnvelope {
    var cards: [VaultCardShard] = []
    override func mapping(map: Map) {
        super.mapping(map: map)
        cards <- map["data.bankCardList"]
    }
}

class VaultCardShard: WireShard {
    var bindRef: String?
    var bankTitle: String?
    var accountMask: String?
    var holderName: String?
    /// IFSC — API `bankCode` / `ifsc`.
    var bankCode: String?
    var accountType: String?
    var creditCard: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        bindRef <- map["bindId"]
        bankTitle <- map["bankName"]
        accountMask <- map["accountNo"]
        holderName <- map["accountName"]
        bankCode <- map["bankCode"]
        accountType <- map["accountType"]
        creditCard <- map["creditCard"]
        if map.mappingType == .fromJSON {
            if (bankCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bankCode = MintConfigShard.parseOptionalString(map["ifsc"].currentValue)
            }
        }
    }
}

class RepayLinkEnvelope: WireEnvelope {
    var shard: RepayLinkShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class RepayLinkShard: WireShard {
    var linkURL: String?
    /// LoanEase `combination` / `connectType` — ignored for jump (always in-app H5 for http(s)).
    var connectType: Int?
    required init?(map: Map) {}
    func mapping(map: Map) {
        if map.mappingType == .fromJSON {
            // LoanEase: between / connect / national / connectUrl / repayUrl
            linkURL = MintConfigShard.parseOptionalString(map["connect"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["between"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["national"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["connectUrl"].currentValue)
                ?? MintConfigShard.parseOptionalString(map["repayUrl"].currentValue)
            connectType = MintConfigShard.parseOptionalInt(map["connectType"].currentValue)
                ?? MintConfigShard.parseOptionalInt(map["combination"].currentValue)
        }
    }
}

class ReleaseNoteEnvelope: WireEnvelope {
    var shard: ReleaseNoteShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class ReleaseNoteShard: WireShard {
    var latestBuild: String?
    var forceBuild: String?
    var storeURL: String?
    var forceStoreURL: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        latestBuild <- map["latestVersion"]
        forceBuild <- map["latestForceVersion"]
        storeURL <- map["latestVersionUrl"]
        forceStoreURL <- map["latestForceVersionUrl"]
    }

    func resolvedStoreURL(force: Bool) -> String? {
        if force {
            let forced = forceStoreURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !forced.isEmpty { return forced }
        }
        let normal = storeURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normal.isEmpty ? nil : normal
    }
}

class EmptyWireEnvelope: WireEnvelope {}

class UploadImageEnvelope: WireEnvelope {
    var shard: UploadImageShard?
    override func mapping(map: Map) {
        super.mapping(map: map)
        shard <- map["data"]
    }
}

class UploadImageShard: WireShard {
    var src: String?
    required init?(map: Map) {}
    func mapping(map: Map) {
        src <- map["src"]
    }
}
