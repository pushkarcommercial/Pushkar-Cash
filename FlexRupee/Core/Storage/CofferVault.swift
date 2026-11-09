import Foundation

enum CofferKey {
    enum Session {
        static let bearerToken = "coffer.session.bearer"
        static let memberId = "coffer.session.memberId"
    }
    enum Mint {
        static let strictHarvest = "coffer.mint.strictHarvest"
        static let contactBatchSize = "coffer.mint.contactBatchSize"
        static let contactBatchCap = "coffer.mint.contactBatchCap"
        static let appLaunchCount = "coffer.mint.appLaunchCount"
        static let ratingVersion = "coffer.mint.ratingVersion"
        static let feedbackGuidance = "coffer.mint.feedbackGuidance"
        static let hubAppUserType = "coffer.mint.hubAppUserType"
        static let rejectH5URL = "coffer.mint.rejectH5URL"
        static let cachedMobile = "coffer.mint.cachedMobile"
    }
}

final class CofferVault {
    static let shared = CofferVault()
    private let defaults = UserDefaults.standard
    private init() {}

    var bearerToken: String {
        get { defaults.string(forKey: CofferKey.Session.bearerToken) ?? "" }
        set { defaults.set(newValue, forKey: CofferKey.Session.bearerToken) }
    }

    var memberId: String {
        get { defaults.string(forKey: CofferKey.Session.memberId) ?? "" }
        set { defaults.set(newValue, forKey: CofferKey.Session.memberId) }
    }

    var isLoggedIn: Bool { !bearerToken.isEmpty }

    func wipeSession() {
        bearerToken = ""
        memberId = ""
        cachedMobileLine = ""
        cachedRejectH5URL = ""
        MintHubStore.shared.clearSessionCache()
    }

    var cachedSupportEmail: String {
        defaults.string(forKey: "coffer.mint.supportEmail") ?? ""
    }

    var cachedSiteURL: String {
        defaults.string(forKey: "coffer.mint.siteURL") ?? ""
    }

    func cacheContactURLs(email: String?, site: String?) {
        if let email { defaults.set(email, forKey: "coffer.mint.supportEmail") }
        if let site { defaults.set(site, forKey: "coffer.mint.siteURL") }
    }

    /// 据量 H5 (`rejectH5`) — LoanEase persists from `/app/config`.
    var cachedRejectH5URL: String {
        get { defaults.string(forKey: CofferKey.Mint.rejectH5URL) ?? "" }
        set { defaults.set(newValue, forKey: CofferKey.Mint.rejectH5URL) }
    }

    func cacheRejectH5URL(_ url: String?) {
        let trimmed = (url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        cachedRejectH5URL = trimmed
    }

    /// Login / profile mobile for 据量 H5 `rejectData` bag.
    var cachedMobileLine: String {
        get { defaults.string(forKey: CofferKey.Mint.cachedMobile) ?? "" }
        set { defaults.set(newValue, forKey: CofferKey.Mint.cachedMobile) }
    }

    var strictContactHarvest: Bool {
        get { defaults.bool(forKey: CofferKey.Mint.strictHarvest) }
        set { defaults.set(newValue, forKey: CofferKey.Mint.strictHarvest) }
    }

    var contactBatchSize: Int {
        get { defaults.integer(forKey: CofferKey.Mint.contactBatchSize) }
        set { defaults.set(newValue, forKey: CofferKey.Mint.contactBatchSize) }
    }

    var contactBatchCap: Int {
        get { defaults.integer(forKey: CofferKey.Mint.contactBatchCap) }
        set { defaults.set(newValue, forKey: CofferKey.Mint.contactBatchCap) }
    }

    var appLaunchCount: Int {
        get { defaults.integer(forKey: CofferKey.Mint.appLaunchCount) }
        set { defaults.set(newValue, forKey: CofferKey.Mint.appLaunchCount) }
    }

    /// From `/app/v3/app/config` `feedbackGuidance`.
    var feedbackGuidance: Int? {
        get {
            guard defaults.object(forKey: CofferKey.Mint.feedbackGuidance) != nil else { return nil }
            return defaults.integer(forKey: CofferKey.Mint.feedbackGuidance)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: CofferKey.Mint.feedbackGuidance)
            } else {
                defaults.removeObject(forKey: CofferKey.Mint.feedbackGuidance)
            }
        }
    }

    /// Cached `suphome.appUserType` (LoanEase `chocolate`) for rating guidance == 2.
    var hubAppUserType: Int? {
        get {
            guard defaults.object(forKey: CofferKey.Mint.hubAppUserType) != nil else { return nil }
            return defaults.integer(forKey: CofferKey.Mint.hubAppUserType)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: CofferKey.Mint.hubAppUserType)
            } else {
                defaults.removeObject(forKey: CofferKey.Mint.hubAppUserType)
            }
        }
    }

    var ratingPromptedForCurrentVersion: Bool {
        defaults.string(forKey: CofferKey.Mint.ratingVersion) == RupeeDeviceProbe.shared.buildStamp
    }

    func markRatingPromptedForCurrentVersion() {
        defaults.set(RupeeDeviceProbe.shared.buildStamp, forKey: CofferKey.Mint.ratingVersion)
    }
}
