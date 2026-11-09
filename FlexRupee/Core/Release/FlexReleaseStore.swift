import Foundation
import ObjectMapper
import RxSwift

final class FlexReleaseStore {
    static let shared = FlexReleaseStore()
    private let wire = PulseWireHub.shared
    private init() {}

    func fetchReleaseNote() -> Single<ReleaseNoteShard> {
        wire.dispatchLenient(.mintRelease(payload: [:]), as: ReleaseNoteEnvelope.self)
            .map { envelope in
                guard envelope.pulseCode == 200 else {
                    throw PulseWireFault.business(code: envelope.pulseCode ?? -1,
                                                  message: envelope.businessMessage)
                }
                return envelope.shard ?? ReleaseNoteShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
            }
    }
}
