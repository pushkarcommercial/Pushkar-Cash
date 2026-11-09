import Foundation
import RxSwift

final class GatePilot {
    let mobileInput = FlexRelay("")
    let otpInput = FlexRelay("")
    let privacyAccepted = FlexRelay(true)
    let termsAccepted = FlexRelay(true)
    let otpCooldown = FlexRelay(0)
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()
    let authenticationFailureSignal = FlexSignal<String>()
    let enterDockSignal = FlexSignal<Void>()

    private let store = GateSessionStore.shared
    private let disposeBag = DisposeBag()
    private var cooldownTimer: Disposable?

    func warmUpRemoteConfig() {
        store.fetchMintConfig()
            .subscribe(onSuccess: { _ in }, onError: { _ in })
            .disposed(by: disposeBag)
    }

    func validateMobileForOTP(_ raw: String) -> String? {
        if raw.trimmingCharacters(in: .whitespaces).isEmpty { return FlexPhraseBook.Gate.mobileEmpty }
        if !RupeeInputGuard.matchesIndiaMobile(raw) { return FlexPhraseBook.Gate.mobileInvalid }
        return nil
    }

    func validateSignIn(mobile: String, otp: String, privacy: Bool) -> String? {
        if !privacy { return FlexPhraseBook.Gate.agreementRequired }
        if mobile.trimmingCharacters(in: .whitespaces).isEmpty { return FlexPhraseBook.Gate.mobileEmpty }
        if !RupeeInputGuard.matchesIndiaMobile(mobile) { return FlexPhraseBook.Gate.mobileInvalid }
        if otp.isEmpty { return FlexPhraseBook.Gate.otpEmpty }
        if !RupeeInputGuard.isValidOTP(otp) { return FlexPhraseBook.Gate.otpInvalid }
        return nil
    }

    func bindOTPTrigger(_ trigger: Observable<Void>) {
        trigger
            .do(onNext: { PulseBeaconRecorder.shared.stamp(.otpRequest) })
            .withLatestFrom(mobileInput.stream)
            .flatMapLatest { [weak self] mobile -> Observable<String> in
                guard let self else { return .empty() }
                if let hint = self.validateMobileForOTP(mobile) {
                    self.toastSignal.accept(hint)
                    return .empty()
                }
                return .just(RupeeInputGuard.normalizedIndiaMobile(mobile))
            }
            .do(onNext: { [weak self] _ in self?.isBusy.accept(true) })
            .flatMapLatest { [weak self] mobile -> Observable<Void> in
                guard let self else { return .empty() }
                return self.store.dispatchOTP(mobile: mobile)
                    .asObservable()
                    .do(onNext: { [weak self] in
                        self?.toastSignal.accept(FlexPhraseBook.Gate.otpSent)
                        self?.startCooldown(seconds: 60)
                    }, onError: { [weak self] error in
                        self?.authenticationFailureSignal.accept(Self.authenticationMessage(for: error,
                                                                                          fallback: FlexPhraseBook.Network.busy))
                    })
                    .catchError { _ in Observable.empty() }
            }
            .subscribe(onNext: { [weak self] _ in self?.isBusy.accept(false) },
                       onError: { [weak self] _ in self?.isBusy.accept(false) })
            .disposed(by: disposeBag)
    }

    func bindSignInTrigger(_ trigger: Observable<Void>) {
        trigger
            .do(onNext: { PulseBeaconRecorder.shared.stamp(.signIn) })
            .withLatestFrom(Observable.combineLatest(mobileInput.stream, otpInput.stream, privacyAccepted.stream))
            .flatMapLatest { [weak self] mobile, otp, privacy -> Observable<(String, String)> in
                guard let self else { return .empty() }
                if let hint = self.validateSignIn(mobile: mobile, otp: otp, privacy: privacy) {
                    self.toastSignal.accept(hint)
                    return .empty()
                }
                return .just((RupeeInputGuard.normalizedIndiaMobile(mobile), otp))
            }
            .do(onNext: { [weak self] _ in self?.isBusy.accept(true) })
            .flatMapLatest { [weak self] mobile, otp -> Observable<Void> in
                guard let self else { return .empty() }
                return self.store.signIn(mobile: mobile, otp: otp)
                    .asObservable()
                    .do(onNext: { [weak self] _ in
                        guard let self else { return }
                        FlexAdjustCoordinator.syncAdidIfLoggedIn()
                        self.enterDockSignal.accept(())
                    })
                    .map { _ in () }
                    .catchError { [weak self] error in
                        self?.authenticationFailureSignal.accept(Self.authenticationMessage(for: error,
                                                                                          fallback: FlexPhraseBook.Gate.signInRejected))
                        return Observable.empty()
                    }
            }
            .subscribe(onNext: { [weak self] _ in self?.isBusy.accept(false) },
                       onError: { [weak self] _ in self?.isBusy.accept(false) })
            .disposed(by: disposeBag)
    }

    private func startCooldown(seconds: Int) {
        cooldownTimer?.dispose()
        otpCooldown.accept(seconds)
        cooldownTimer = Observable<Int>.interval(1, scheduler: MainScheduler.instance)
            .take(seconds)
            .subscribe(onNext: { [weak self] tick in
                self?.otpCooldown.accept(seconds - tick - 1)
            }, onCompleted: { [weak self] in
                self?.otpCooldown.accept(0)
            })
    }

    private static func authenticationMessage(for error: Error, fallback: String) -> String {
        guard let fault = error as? PulseWireFault else { return fallback }
        if case .business(_, let message) = fault {
            let serverMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if fallback == FlexPhraseBook.Gate.signInRejected {
                let normalized = serverMessage.lowercased()
                if normalized.contains("otp") || normalized.contains("verification code")
                    || normalized.contains("verify code") || normalized.contains("invalid code")
                    || normalized.contains("wrong code") || normalized.contains("验证码") {
                    return FlexPhraseBook.Gate.otpInvalid
                }
            }
            return serverMessage.isEmpty ? fallback : serverMessage
        }
        return fault.message(or: fallback)
    }
}

extension PulseWireFault: CustomStringConvertible {
    var description: String {
        switch self {
        case .transport: return FlexPhraseBook.Network.busy
        case .decode: return FlexPhraseBook.Network.decodeFailed
        case .business(_, let msg): return msg
        case .sessionExpired: return FlexPhraseBook.Network.sessionExpired
        case .versionBlocked: return FlexPhraseBook.Network.updateRequired
        }
    }
}
