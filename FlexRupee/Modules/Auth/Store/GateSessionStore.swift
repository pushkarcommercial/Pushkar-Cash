import Foundation
import ObjectMapper
import RxSwift

final class GateSessionStore {
    static let shared = GateSessionStore()
    private let wire = PulseWireHub.shared
    private let registrationBag = DisposeBag()
    private init() {}

    func dispatchOTP(mobile: String) -> Single<Void> {
        wire.dispatchVoid(.gateOTP(payload: [
            "mobile": mobile,
            "verifyType": "1"
        ]))
    }

    func signIn(mobile: String, otp: String) -> Single<GateTokenShard> {
        wire.dispatchLenient(.gateSignIn(payload: [
            "mobile": mobile,
            "verifyCode": otp,
            "latitude": "-360",
            "longitude": "-360",
            "serialNo": RupeeDeviceProbe.shared.deviceFingerprint,
            "imei": ""
        ]), as: GateTokenEnvelope.self)
        .map { envelope in
            if let code = envelope.pulseCode, code != 200 {
                let message = envelope.serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw PulseWireFault.business(code: code, message: message)
            }
            guard let shard = envelope.shard, let token = shard.bearerToken, !token.isEmpty else { throw PulseWireFault.decode }
            CofferVault.shared.bearerToken = shard.bearerToken ?? ""
            CofferVault.shared.memberId = shard.memberId ?? ""
            let digits = mobile.trimmingCharacters(in: .whitespacesAndNewlines)
            if !digits.isEmpty { CofferVault.shared.cachedMobileLine = digits }
            return shard
        }
        .do(onSuccess: { [weak self] _ in
            guard let self else { return }
            // Session-owned subscription survives disposal of the login screen.
            self.registerDevice()
                .subscribe(onSuccess: { _ in }, onError: { _ in })
                .disposed(by: self.registrationBag)
        })
    }

    func registerDevice() -> Single<Void> {
        Single.create { single in
            var inner: Disposable?
            RupeeDeviceProbe.shared.buildSyncPayload { payload in
                inner = PulseWireHub.shared.dispatchVoid(.gateRegisterDevice(payload: payload))
                    .subscribe(onSuccess: { single(.success(())) },
                               onError: { single(.error($0)) })
            }
            return Disposables.create { inner?.dispose() }
        }
    }

    func fetchMintConfig() -> Single<MintConfigShard> {
        wire.dispatch(.mintConfig(payload: [:]), as: MintConfigEnvelope.self)
            .map { envelope in
                let shard = envelope.shard ?? MintConfigShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
                // Legal / Contact Us H5 URLs are hardcoded on FlexLegalDocKind — not from config.
                CofferVault.shared.cacheContactURLs(email: shard.supportEmail, site: shard.siteURL)
                CofferVault.shared.cacheRejectH5URL(shard.rejectH5URL)
                RupeeConsentGate.shared.applyMintConfig(shard)
                return shard
            }
    }

    func signOut() -> Single<Void> {
        wire.dispatchVoid(.gateSignOut(payload: [:]))
            .do(onSuccess: { CofferVault.shared.wipeSession() })
    }
}
