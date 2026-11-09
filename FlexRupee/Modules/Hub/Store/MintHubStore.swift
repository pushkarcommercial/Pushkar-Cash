import Foundation
import ObjectMapper
import RxSwift

enum OfferTermOutcome {
    case ready(OfferCardShard)
    case pendingReview(message: String, dealId: String?)
    case pendingWithdraw(message: String, dealId: String?)
}

final class MintHubStore {
    static let shared = MintHubStore()
    private let wire = PulseWireHub.shared
    private init() {}

    /// Last successful `suphome` payload — used by recommend result (LoanEase `lastResponse`).
    private(set) var lastSnapshot: HubSnapshotShard?

    func clearSessionCache() {
        lastSnapshot = nil
    }

    func loadSnapshot() -> Single<HubSnapshotShard> {
        wire.dispatch(.hubSnapshot(payload: ["dcUpFlag": "1"]), as: HubSnapshotEnvelope.self)
            .map { [weak self] envelope in
                let shard = envelope.shard ?? HubSnapshotShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                self?.lastSnapshot = shard
                RupeeConsentGate.shared.applyHarvestFlag(shard.harvestContactsFlag)
                RupeeConsentGate.shared.applyHubAppUserType(shard.memberTier)
                return shard
            }
    }

    func loadOffers() -> Single<[OfferCardShard]> {
        wire.dispatch(.hubOffers(payload: [:]), as: OfferDeckEnvelope.self).map { $0.cards }
    }

    /// Manual Apply / matching page — `/product/dcRecommend` (4102007 may open in-app H5).
    func fetchManualRecommend(productLabel: String? = nil) -> Single<OfferDeckEnvelope> {
        wire.dispatchLenient(.hubRecommendManual(payload: Self.recommendPayload(productLabel)),
                             as: OfferDeckEnvelope.self)
    }

    /// Home auto-order — same path, separate route entry (no 4102007 H5 business).
    func fetchAutoRecommend(productLabel: String? = nil) -> Single<OfferDeckEnvelope> {
        wire.dispatchLenient(.hubRecommendAuto(payload: Self.recommendPayload(productLabel)),
                             as: OfferDeckEnvelope.self)
    }

    private static func recommendPayload(_ productLabel: String?) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let label = productLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            payload["productLabel"] = label
        }
        return payload
    }

    func loadOfferTerms(productId: String) -> Single<OfferCardShard> {
        loadOfferTermsResult(productId: productId)
            .flatMap { outcome -> Single<OfferCardShard> in
                switch outcome {
                case .ready(let card):
                    return .just(card)
                case .pendingReview(let message, _):
                    return .error(PulseWireFault.business(code: 6230002, message: message))
                case .pendingWithdraw(let message, _):
                    return .error(PulseWireFault.business(code: 6230003, message: message))
                }
            }
    }

    func loadOfferTermBundle(productId: String) -> Single<OfferTermBundleShard> {
        wire.dispatchLenient(.hubOfferTerms(payload: ["productId": productId]), as: OfferTermEnvelope.self)
            .map { envelope in
                switch envelope.pulseCode {
                case 200:
                    return envelope.bundle ?? OfferTermBundleShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                case 6230002, 6230003:
                    throw PulseWireFault.business(code: envelope.pulseCode ?? -1,
                                                  message: envelope.businessMessage)
                default:
                    throw PulseWireFault.business(code: envelope.pulseCode ?? -1,
                                                  message: envelope.businessMessage)
                }
            }
    }

    func loadOfferTermsResult(productId: String) -> Single<OfferTermOutcome> {
        wire.dispatchLenient(.hubOfferTerms(payload: ["productId": productId]), as: OfferTermEnvelope.self)
            .map { envelope in
                switch envelope.pulseCode {
                case 200:
                    let card = envelope.card ?? OfferCardShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                    return .ready(card)
                case 6230002:
                    return .pendingReview(message: envelope.businessMessage,
                                          dealId: envelope.card?.dealId)
                case 6230003:
                    return .pendingWithdraw(message: envelope.businessMessage,
                                            dealId: envelope.card?.dealId)
                default:
                    throw PulseWireFault.business(code: envelope.pulseCode ?? -1,
                                                  message: envelope.businessMessage)
                }
            }
    }

    func syncDevice(orderId: String, devicePayload: [String: Any]) -> Single<Void> {
        var payload = devicePayload
        payload["orderId"] = orderId
        return wire.dispatchVoid(.hubDeviceSync(payload: payload))
    }

    func syncContacts(orderId: String, list: [[String: String]]) -> Single<Void> {
        wire.dispatchVoid(.hubContactSync(payload: ["orderId": orderId, "list": list]))
    }

    func markDealReady(orderId: String, allowContact: String?) -> Single<Void> {
        var payload: [String: Any] = ["orderId": orderId]
        if let allowContact { payload["allowContact"] = allowContact }
        return wire.dispatchVoid(.hubDealReady(payload: payload))
    }

    func loadVerifyStages() -> Single<[VerifyStageShard]> {
        wire.dispatch(.verifyStages(payload: [:]), as: VerifyStageEnvelope.self).map { $0.stages }
    }

    /// Unified order submit (`/order/userSubmitDcUpgrade`) — single or multi product.
    /// Success (resultCode == 200): require non-empty `data.list[].orderId`;
    /// empty list → business fault, no harvest.
    func submitDeal(payload: [String: Any]) -> Single<MintConfigShard> {
        wire.dispatch(.hubSubmitDeal(payload: payload), as: MintConfigEnvelope.self)
            .map { envelope in
                let code = envelope.pulseCode ?? -1
                let shard = envelope.shard ?? MintConfigShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                let orderId = shard.spawnedDealId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard code == 200, !orderId.isEmpty else {
                    let apiMsg = envelope.serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    throw PulseWireFault.business(
                        code: code,
                        message: apiMsg.isEmpty ? FlexPhraseBook.Consent.uploadFailed : apiMsg
                    )
                }
                return shard
            }
    }

    func submitFeedback(content: String, images: [String]) -> Single<Void> {
        wire.dispatchVoid(.hubFeedback(payload: [
            "description": content,
            "pictureUrl": images.joined(separator: ",")
        ]))
    }

    func uploadFeedbackImage(_ jpegData: Data) -> Single<String> {
        let fileName = "feedback_\(Int(Date().timeIntervalSince1970)).jpg"
        return wire.dispatch(.hubUploadImage(jpegData: jpegData, fileName: fileName), as: UploadImageEnvelope.self)
            .map { envelope in
                guard let url = envelope.shard?.src?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !url.isEmpty else {
                    throw PulseWireFault.decode
                }
                return url
            }
    }
}
