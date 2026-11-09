import Foundation
import RxSwift

final class VerifyStagePilot {
    let fields = FlexRelay<[VerifyFieldShard]>([])
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()
    let completed = FlexSignal<Void>()
    /// Fired for unclear-document codes (6212011 / 6212201) → auth error sheet.
    let documentUnclear = FlexSignal<Void>()

    private let store = VerifyStageStore.shared
    private let disposeBag = DisposeBag()
    private let stageKind: String
    private var stageId = ""

    init(stageKind: String) {
        self.stageKind = stageKind
    }

    func bootstrap(stageId: String?) {
        self.stageId = stageId ?? ""
        guard !self.stageId.isEmpty else { return }
        isBusy.accept(true)
        store.loadForm(stageId: self.stageId)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] form in
                let sorted = form.fields.sorted { ($0.itemSort ?? 0) < ($1.itemSort ?? 0) }
                self?.fields.accept(sorted)
                self?.isBusy.accept(false)
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    func submit(values: [String: String]) {
        let missing = fields.value.first { field in
            guard field.requiresInput else { return false }
            let code = field.fieldCode ?? ""
            let value = values[code] ?? ""
            if value.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return false
        }
        if let miss = missing {
            let label = miss.fieldLabel ?? miss.fieldCode ?? "Field"
            let format = !miss.options.isEmpty
                ? FlexPhraseBook.Verify.selectRequiredFormat
                : FlexPhraseBook.Verify.fieldEmptyFormat
            let hint = String(format: format, label)
            toastSignal.accept(hint)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: hint)
            return
        }

        let payload = values.map { key, value in
            ["itemCode": key, "itemValue": value, "itemValueType": "1"]
        }
        commitItems(payload)
    }

    func submitSingleField(itemCode: String, value: String) {
        guard !stageId.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Verify.stagesUnavailable)
            return
        }
        isBusy.accept(true)
        FlexSpinnerOverlay.beginRequest()
        emitStageBeacon()
        store.commitTextItem(stageId: stageId, itemCode: itemCode, value: value)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                self?.completed.accept(())
            }, onError: { [weak self] error in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                if PulseWireFault.isUnclearDocument(error) {
                    Self.recordUnclearDocument(error)
                    self?.documentUnclear.accept(())
                } else {
                    self?.toastSignal.accept((error as? PulseWireFault)?.message(or: FlexPhraseBook.Verify.formRejected) ?? FlexPhraseBook.Network.busy)
                }
            })
            .disposed(by: disposeBag)
    }

    func uploadImage(itemCode: String, base64: String,
                     onCardNo: @escaping (String?) -> Void,
                     onFailure: (() -> Void)? = nil) {
        guard !stageId.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Verify.stagesUnavailable)
            FlexSpinnerOverlay.endRequest()
            onFailure?()
            return
        }
        isBusy.accept(true)
        store.commitImageItem(stageId: stageId, itemCode: itemCode, base64: base64)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] shard in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                onCardNo(shard.echoMap?.cardNo)
            }, onError: { [weak self] error in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                // Auth error sheet only for 6212011 / 6212201; all other codes toast backend copy.
                if PulseWireFault.isUnclearDocument(error) {
                    Self.recordUnclearDocument(error)
                    self?.documentUnclear.accept(())
                } else {
                    self?.toastSignal.accept(
                        PulseWireFault.backendCopy(from: error, fallback: FlexPhraseBook.Verify.imageUploadFailed)
                    )
                    onFailure?()
                }
            })
            .disposed(by: disposeBag)
    }

    func submitLiveness(imageBase64: String) {
        guard !stageId.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Verify.stagesUnavailable)
            return
        }
        isBusy.accept(true)
        FlexSpinnerOverlay.beginRequest()
        store.submitLiveness(stageId: stageId, imageBase64: imageBase64)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                self?.completed.accept(())
            }, onError: { [weak self] error in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                PulseBeaconRecorder.shared.stamp(.verifyFaceFailure)
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func commitItems(_ items: [[String: Any]]) {
        guard !stageId.isEmpty else {
            toastSignal.accept(FlexPhraseBook.Verify.stagesUnavailable)
            return
        }
        isBusy.accept(true)
        FlexSpinnerOverlay.beginRequest()
        emitStageBeacon()
        store.commitStage(stageId: stageId, items: items)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                self?.completed.accept(())
            }, onError: { [weak self] error in
                FlexSpinnerOverlay.endRequest()
                self?.isBusy.accept(false)
                if PulseWireFault.isUnclearDocument(error) {
                    Self.recordUnclearDocument(error)
                    self?.documentUnclear.accept(())
                } else {
                    self?.toastSignal.accept((error as? PulseWireFault)?.message(or: FlexPhraseBook.Verify.formRejected) ?? FlexPhraseBook.Network.busy)
                }
            })
            .disposed(by: disposeBag)
    }

    private func emitStageBeacon() {
        switch stageKind {
        case "personal": PulseBeaconRecorder.shared.stamp(.verifyPersonalSubmit)
        case "work": PulseBeaconRecorder.shared.stamp(.verifyWorkSubmit)
        case "questionnaire": PulseBeaconRecorder.shared.stamp(.verifyCreditSubmit)
        case "urgent_contact": PulseBeaconRecorder.shared.stamp(.verifyEmergencySubmit)
        case "pay_account": PulseBeaconRecorder.shared.stamp(.verifyBankSubmit)
        case "liveness": PulseBeaconRecorder.shared.stamp(.verifyFaceStart)
        case "identity": PulseBeaconRecorder.shared.stamp(.verifyIdentitySubmit)
        // PAN submit (40) is stamped on the button tap in VerifyPanCanvas — avoid double-fire here.
        case "tax": break
        default: break
        }
    }

    private static func recordUnclearDocument(_ error: Error) {
        guard let fault = error as? PulseWireFault,
              case .business(let code, let message) = fault else { return }
        PulseBeaconRecorder.shared.stamp(.verifyFaceFailure)
        PulseBeaconRecorder.shared.stamp(.verifyCertificateInvalid,
                                         note: String(code),
                                         remark2: message)
    }
}
