import Foundation
import RxSwift

/// Server bury/record event codes — aligned with Kiva CrediLink `CLEventTrackingTool`.
enum PulseBeaconTag: Int {
    case coldLaunch = 0
    case warmOpen = 1
    case privacyLink = 2
    case termsLink = 3
    case otpRequest = 4
    case signIn = 5
    case hubApplyTap = 7
    case cameraGranted = 11
    case cameraDenied = 12
    case albumGranted = 13
    case albumDenied = 14
    case locationGranted = 15
    case locationDenied = 16
    case idfaGranted = 17
    case idfaDenied = 18
    case contactsGranted = 19
    case contactsDenied = 20
    case verifyFieldFail = 29
    case verifyPersonalSubmit = 30
    case verifyWorkSubmit = 31
    case verifyEmergencySubmit = 32
    case verifyEmergencyPick = 33
    case verifyCreditSubmit = 34
    case verifyFaceStart = 35
    case verifyFaceFailure = 37
    case verifyCertificateInvalid = 38
    case verifyFaceCapture = 39
    case verifyPanConfirm = 40
    /// PAN / tax card photo flow (KYC-P卡-印度) — distinct from Aadhaar 50–57.
    case panSelectPhoto = 41
    case panSelectCamera = 42
    case panOpenCamera = 43
    case panCapturePhoto = 44
    case panConfirmPhoto = 45
    case panRetakePhoto = 46
    case panCancelCamera = 47
    case panSelectAlbum = 48
    case panAlbumSelectPhoto = 49
    case identitySelectPhoto = 50
    case identitySelectCamera = 51
    case identitySelectAlbum = 52
    case identityOpenCamera = 53
    case identityCapturePhoto = 54
    case identityConfirmPhoto = 55
    case identityCancelCamera = 56
    case identityAlbumSelectPhoto = 57
    case verifyIdentitySubmit = 66
    case verifyBankSubmit = 67
    case loanConfirmSubmit = 68
    case autoApplyTriggered = 72
    case contactsLimited = 198
    /// 据量 H5 `thirdUrl` open (BrightFuture / LoanEase event 502).
    case rejectH5Open = 502

    /// Legacy alias — OTP and Sign-In used to share one code.
    static let otpOrSignIn = PulseBeaconTag.otpRequest
}

final class PulseBeaconRecorder {
    static let shared = PulseBeaconRecorder()
    private let wire = PulseWireHub.shared
    private let disposeBag = DisposeBag()
    private var didStampLaunchSession = false
    private init() {}

    func stamp(_ tag: PulseBeaconTag, note: String = "NULL", remark2: String = "NULL") {
        let payload: [String: Any] = [
            "eventCode": "\(tag.rawValue)",
            "eventContent": "NULL",
            "remark1": note.isEmpty ? "NULL" : note,
            "remark2": remark2.isEmpty ? "NULL" : remark2,
            "remark3": "NULL"
        ]
        // Sign with full data body (Kiva/FinTrust) — MintRoute default payloadBody path.
        wire.dispatchVoid(.hubTrackEvent(payload: payload))
            .subscribe(onSuccess: { _ in }, onError: { _ in })
            .disposed(by: disposeBag)
    }

    /// Kiva AppDelegate: after network, always stamp `1`; first install also stamps `0`.
    func stampLaunchAfterNetworkReady() {
        guard !didStampLaunchSession else { return }
        didStampLaunchSession = true
        stamp(.warmOpen)
        if FlexNetworkWatch.isFirstInstallLaunch() {
            stamp(.coldLaunch)
        }
    }
}
