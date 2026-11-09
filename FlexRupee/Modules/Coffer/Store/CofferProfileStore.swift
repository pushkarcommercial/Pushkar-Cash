import Foundation
import ObjectMapper
import RxSwift

final class CofferProfileStore {
    static let shared = CofferProfileStore()
    private let wire = PulseWireHub.shared
    private init() {}

    /// Profile fetch only — Adjust adid uses `hubAdjustSync`, not this call.
    func loadProfile() -> Single<MintProfileShard> {
        wire.dispatch(.hubMember(payload: [:]), as: MintProfileEnvelope.self)
            .map { envelope in
                let shard = envelope.shard ?? MintProfileShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                if let mobile = shard.mobileLine?.trimmingCharacters(in: .whitespacesAndNewlines), !mobile.isEmpty {
                    CofferVault.shared.cachedMobileLine = mobile
                }
                return shard
            }
    }

    func loadCards() -> Single<[VaultCardShard]> {
        wire.dispatch(.vaultCards(payload: [:]), as: VaultCardEnvelope.self).map { $0.cards }
    }

    func editCard(payload: [String: Any]) -> Single<Void> {
        wire.dispatchVoid(.vaultEditCard(payload: payload))
    }

    func retireAccount() -> Single<Void> {
        wire.dispatchVoid(.gateRetire(payload: [:]))
            .do(onSuccess: { CofferVault.shared.wipeSession() })
    }
}
