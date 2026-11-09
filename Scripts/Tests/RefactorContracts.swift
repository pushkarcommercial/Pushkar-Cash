import Foundation
import ObjectMapper

@main
struct RefactorContracts {
    static var passed = 0
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else { fatalError("FAIL: \(name)") }
        passed += 1
        print("PASS: \(name)")
    }

    static func main() {
        // Test the application's real ObjectMapper models; never contact a service.
        for key in ["rejectH5", "reject_h5"] {
            let config = Mapper<MintConfigShard>().map(JSON: [key: "  https://recommend.invalid/page  "])!
            check(config.rejectH5URL == "https://recommend.invalid/page", "config reads \(key)")
            let nested = Mapper<MintConfigShard>().map(JSON: ["dynamicParameter": [key: "https://nested.invalid/page"]])!
            check(nested.rejectH5URL == "https://nested.invalid/page", "config reads nested \(key)")
        }
        let empty = Mapper<MintConfigShard>().map(JSON: ["rejectH5": NSNull()])!
        check(empty.rejectH5URL == nil, "missing reject link stays missing")
        let config = Mapper<MintConfigShard>().map(JSON: ["preceding": "1", "sore": "50", "pushMaxCount": "500", "withdrawn": "2"])!
        check(config.fetchContactsFlag == 1, "strict permission flag preserved")
        check(config.contactBatchSize == "50" && config.contactBatchCap == "500", "contact batching reads config pushPerCount/pushMaxCount")
        check(config.feedbackGuidance == 2, "rating guidance remains available")
        let clearBatch = Mapper<MintConfigShard>().map(JSON: ["pushPerCount": "30", "pushMaxCount": "200"])!
        check(clearBatch.contactBatchSize == "30" && clearBatch.contactBatchCap == "200", "contact batching prefers clear config keys")
        let discarded = Mapper<MintConfigShard>().map(JSON: ["dynamicParameter": ["fjtip": "on"], "impress": "unused", "smart": "unused"])!.toJSON()
        check(discarded["dynamicParameter"] == nil && discarded["impress"] == nil && discarded["smart"] == nil, "retired configuration fields are ignored")

        for code in [2000001, 2000002, 2002001, 2009006, 6212009, 6212011, 6212201, 6230002, 6230003, 6234303, 4102007, 999999] {
            let envelope = Mapper<WireEnvelope>().map(JSON: ["psychological": code, "efficiency": "REMOTE_COPY_MUST_NOT_RENDER", "msg": "REMOTE_COPY_MUST_NOT_RENDER"])!
            check(envelope.pulseCode == code && envelope.localMessage == FlexPhraseBook.Network.message(for: code), "code \(code) uses local copy")
            check(envelope.toJSON()["efficiency"] == nil && envelope.toJSON()["msg"] == nil, "code \(code) discards remote prose")
        }
        check(FlexPhraseBook.Network.message(for: 2000001) == FlexPhraseBook.Network.sessionExpired, "session-expiry meaning preserved")
        check(FlexPhraseBook.Network.message(for: 6230003) == FlexPhraseBook.Hub.withdrawPending, "pending withdrawal meaning preserved")
        check(FlexPhraseBook.Network.message(for: 4102007) == FlexPhraseBook.Hub.noRecommendCopy, "recommendation rejection meaning preserved")
        check(!FlexPhraseBook.Network.message(for: nil).isEmpty, "missing code has local fallback")

        let submitted: [[String: Any]] = [
            ["list": [["billion": "order-a"]]],
            ["camel": [["orderId": "order-a"]]],
            ["orderIdList": ["order-a"]],
            ["orderIds": ["order-a"]],
            ["billion": "order-a"]
        ]
        for (index, body) in submitted.enumerated() {
            let result = Mapper<MintConfigShard>().map(JSON: body)!
            check(result.spawnedDealId == "order-a", "submit order identity shape \(index) preserved")
            check(result.spawnedDealIds == ["order-a"], "submit order ids list shape \(index) preserved")
        }
        let multi = Mapper<MintConfigShard>().map(JSON: ["orderIdList": ["order-a", "order-b"]])!
        check(multi.spawnedDealIds == ["order-a", "order-b"] && multi.spawnedDealId == "order-a",
              "batch submit keeps all order ids")
        check(Mapper<MintConfigShard>().map(JSON: ["list": []])!.spawnedDealId == nil, "empty submit list is not success identity")

        let snapshot = Mapper<HubSnapshotShard>().map(JSON: [
            "userStatus": 20,
            "appUserType": "2",
            "hasOrder": false,
            "firstLoanOptionLine": "system",
            "promptCopy": "REMOTE_BANNER",
            "plug": "LEGACY_PLUG"
        ])!
        check(snapshot.memberState == 20 && snapshot.prefersSystemAutoPlace, "home eligibility fields preserved")
        check(snapshot.memberTier == "2", "home rating member type preserved")
        check(snapshot.promoCopy == "REMOTE_BANNER", "home message area prefers clear promptCopy")
        let plugOnly = Mapper<HubSnapshotShard>().map(JSON: ["plug": "FROM_PLUG"])!
        check(plugOnly.promoCopy == "FROM_PLUG", "home message area falls back to plug alias")
        check(HubMemberPhase.withdrawPending.bannerMessage == FlexPhraseBook.Hub.withdrawPending, "home withdraw banner local fallback kept")
        check(HubMemberPhase.verifyPending.bannerMessage == FlexPhraseBook.Hub.kycBanner, "home KYC banner local fallback kept")

        let order = Mapper<LedgerDetailShard>().map(JSON: ["machinery": ["billion": "order-a", "intellectual": 60, "furnish": "1000", "grey": "1"], "message": "REMOTE_FOOTER"])!
        check(order.dealId == "order-a" && order.dealState == 60 && order.canExtend == "1", "order action fields preserved")
        check(order.toJSON()["message"] == nil, "order footer is not backend prose")
        let release = Mapper<ReleaseNoteShard>().map(JSON: ["upload": "9.0", "flavour": "2.0", "slide": "https://store.invalid/latest", "eighty": "https://store.invalid/required", "carouselData": "unused", "spin": "unused"])!
        check(release.resolvedStoreURL(force: false) == "https://store.invalid/latest", "normal upgrade destination retained")
        check(release.resolvedStoreURL(force: true) == "https://store.invalid/required", "required upgrade destination retained")
        check(release.toJSON()["carouselData"] == nil && release.toJSON()["spin"] == nil, "unused release prose removed")

        let field = Mapper<VerifyFieldShard>().map(JSON: ["suspend": "email", "local": "Email", "spill": 1, "isRequired": "1", "noun": "test-pattern"])!
        check(field.fieldCode == "email" && field.isMandatory == "1" && field.patternRule == "test-pattern", "KYC schema and validation metadata preserved")
        let tier = Mapper<OfferTermBundleShard>().map(JSON: ["kindness": "product-a", "upper": [["furnish": "1000", "propose": [["giant": 7, "complaint": 7]]], ["furnish": "2000", "propose": [["giant": 14, "complaint": 14]]]]])!
        check(tier.highestAmountIndex() == 1, "recommendation amount selection preserved")
        check(tier.highestTermIndex(in: tier.tiers[1]) == 0, "recommendation term selection preserved")
        check(String(format: FlexPhraseBook.Verify.fieldEmptyFormat, "Email").contains("Email"), "local field error keeps field context")
        print("\(passed) model/copy contracts passed. No network calls or runtime permission changes.")
    }
}
