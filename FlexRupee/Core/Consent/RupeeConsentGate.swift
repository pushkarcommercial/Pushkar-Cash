import Foundation

/// Strong collection is tied to `retrieveMobileContact == 1` (same as TrustLoan/Kiva).
final class RupeeConsentGate {
    static let shared = RupeeConsentGate()

    private init() {}

    var requiresStrictHarvest: Bool {
        CofferVault.shared.strictContactHarvest
    }

    func applyMintConfig(_ shard: MintConfigShard?) {
        guard let shard else { return }
        CofferVault.shared.strictContactHarvest = shard.fetchContactsFlag == 1
        // Persist pushPerCount / pushMaxCount exactly as config returned.
        if let raw = shard.contactBatchSize?.trimmingCharacters(in: .whitespacesAndNewlines),
           let per = Int(raw) {
            CofferVault.shared.contactBatchSize = per
        }
        if let raw = shard.contactBatchCap?.trimmingCharacters(in: .whitespacesAndNewlines),
           let cap = Int(raw) {
            CofferVault.shared.contactBatchCap = cap
        }
        CofferVault.shared.feedbackGuidance = shard.feedbackGuidance
    }

    func applyHarvestFlag(_ flag: Int?) {
        guard let flag else { return }
        CofferVault.shared.strictContactHarvest = flag == 1
    }

    func applyHubAppUserType(_ raw: String?) {
        guard let raw,
              let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        CofferVault.shared.hubAppUserType = value
    }

    func fallbackCoordinates() -> (lat: String, lng: String) {
        ("-360", "-360")
    }
}
