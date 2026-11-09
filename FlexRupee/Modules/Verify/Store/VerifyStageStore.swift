import Foundation
import ObjectMapper
import RxSwift

final class VerifyStageStore {
    static let shared = VerifyStageStore()
    private let wire = PulseWireHub.shared
    private init() {}

    func loadForm(stageId: String) -> Single<VerifyFormShard> {
        wire.dispatch(.verifyForm(payload: ["kycId": stageId]), as: VerifyFormEnvelope.self)
            .map { $0.shard ?? VerifyFormShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    func commitStage(stageId: String, items: [[String: Any]]) -> Single<Void> {
        wire.dispatchVoid(.verifyCommit(payload: [
            "kycId": stageId,
            "kycCommitItemList": items
        ]))
    }

    func commitField(stageId: String, payload: [String: Any]) -> Single<Void> {
        var body = payload
        body["kycId"] = stageId
        return wire.dispatchVoid(.verifyFieldCommit(payload: body))
    }

    func submitLiveness(stageId _: String, imageBase64: String) -> Single<Void> {
        // Kiva silent API: data + sign only contain `liveness` (no kycId).
        wire.dispatchVoid(.verifyLiveness(payload: [
            "liveness": imageBase64
        ]))
    }

    func commitImageItem(stageId: String, itemCode: String, base64: String) -> Single<VerifyItemCommitShard> {
        var body: [String: Any] = [
            "itemCode": itemCode,
            "itemValue": base64,
            "itemValueType": "2"
        ]
        body["kycId"] = stageId
        return wire.dispatch(.verifyFieldCommit(payload: body), as: VerifyItemCommitEnvelope.self)
            .map { $0.shard ?? VerifyItemCommitShard(map: Map(mappingType: .fromJSON, JSON: [:]))! }
    }

    func commitTextItem(stageId: String, itemCode: String, value: String) -> Single<Void> {
        commitField(stageId: stageId, payload: [
            "itemCode": itemCode,
            "itemValue": value,
            "itemValueType": "1"
        ])
    }

    func fetchIFSCList(payload: [String: Any]) -> Single<[String]> {
        wire.dispatch(.verifyIFSC(payload: payload), as: IFSCListEnvelope.self)
            .map { $0.list }
    }
}
