import Foundation
import Moya
import Alamofire

enum MintRoute {
    case gateOTP(payload: [String: Any])
    case gateSignIn(payload: [String: Any])
    case gateSignOut(payload: [String: Any])
    case gateRetire(payload: [String: Any])
    case gateRegisterDevice(payload: [String: Any])
    case mintConfig(payload: [String: Any])
    case mintRelease(payload: [String: Any])
    case hubSnapshot(payload: [String: Any])
    case hubOffers(payload: [String: Any])
    /// Manual Apply / matching page → `/product/dcRecommend` (may handle 4102007 H5).
    case hubRecommendManual(payload: [String: Any])
    /// Home auto-order → same path, separate entry (no 4102007 H5 business).
    case hubRecommendAuto(payload: [String: Any])
    case hubOfferTerms(payload: [String: Any])
    case hubMember(payload: [String: Any])
    case hubAdjustSync(payload: [String: Any])
    case hubSubmitDeal(payload: [String: Any])
    case hubDeviceSync(payload: [String: Any])
    case hubContactSync(payload: [String: Any])
    case hubDealReady(payload: [String: Any])
    case hubFeedback(payload: [String: Any])
    case hubUploadImage(jpegData: Data, fileName: String)
    case hubTrackEvent(payload: [String: Any])
    case ledgerRows(payload: [String: Any])
    case ledgerDetail(payload: [String: Any])
    case ledgerWithdraw(payload: [String: Any])
    case ledgerWithdrawInfo(payload: [String: Any])
    case ledgerRepayLink(payload: [String: Any])
    case ledgerExtend(payload: [String: Any])
    case verifyStages(payload: [String: Any])
    case verifyForm(payload: [String: Any])
    case verifyCommit(payload: [String: Any])
    case verifyFieldCommit(payload: [String: Any])
    case verifyLiveness(payload: [String: Any])
    case verifyIFSC(payload: [String: Any])
    case vaultCards(payload: [String: Any])
    case vaultEditCard(payload: [String: Any])
}

extension MintRoute: TargetType {
    var baseURL: URL { FlexServiceEndpoint.baseURL }

    var path: String {
        switch self {
        case .gateOTP: return "/app/v3/sms/sendVerifySms"
        case .gateSignIn: return "/app/v3/auth/registerOrLogin"
        case .gateSignOut: return "/app/v3/auth/logout"
        case .gateRetire: return "/app/v3/auth/close"
        case .gateRegisterDevice: return "/app/v3/mobile/registerDevice"
        case .mintConfig: return "/app/v3/app/config"
        case .mintRelease: return "/app/v3/app/version"
        case .hubSnapshot: return "/app/v3/user/suphome"
        case .hubOffers: return "/app/v3/product/list"
        case .hubRecommendManual, .hubRecommendAuto: return "/app/v3/product/dcRecommend"
        case .hubOfferTerms: return "/app/v3/product/termV3"
        case .hubMember: return "/app/v3/user/info"           // profile fetch
        case .hubAdjustSync: return "/app/v3/user/info"       // adid upload only
        case .hubSubmitDeal: return "/app/v3/order/userSubmitDcUpgrade"
        case .hubDeviceSync: return "/app/v3/mobile/device"
        case .hubContactSync: return "/app/v3/mobile/contact"
        case .hubDealReady: return "/app/v3/order/ready"
        case .hubFeedback: return "/app/v3/user/problemFeedback"
        case .hubUploadImage: return "/app/v3/sys/upload"
        case .hubTrackEvent: return "/app/v3/bury/record"
        case .ledgerRows: return "/app/v3/order/list"
        case .ledgerDetail: return "/app/v3/order/detailV2"
        case .ledgerWithdraw: return "/app/v3/order/apply/withdrawal"
        case .ledgerWithdrawInfo: return "/app/v3/order/withdrawn/detail"
        case .ledgerRepayLink: return "/app/v3/order/repay/connect"
        case .ledgerExtend: return "/app/v3/order/repay/extension"
        case .verifyStages: return "/app/v3/kyc/status"
        case .verifyForm: return "/app/v3/kyc/init"
        case .verifyCommit: return "/app/v3/kyc/commit"
        case .verifyFieldCommit: return "/app/v3/kyc/item/commit"
        case .verifyLiveness: return "/app/v3/kyc/liveness/silent"
        case .verifyIFSC: return "/app/v3/sys/ifsc"
        case .vaultCards: return "/app/v3/bankcard/list"
        case .vaultEditCard: return "/app/v3/bankcard/modify"
        }
    }

    var method: Moya.Method { .post }

    var sampleData: Data { Data() }

    var task: Task {
        switch self {
        case .hubUploadImage(let jpegData, let fileName):
            return .uploadCompositeMultipart(
                MintStampBuilder.shared.weaveUploadMultipart(jpegData: jpegData, fileName: fileName),
                urlParameters: [:]
            )
        default:
            break
        }
        let envelope = MintStampBuilder.shared.weaveEnvelope(
            dataPayload: payloadBody,
            signPayload: signPayloadBody
        )
        guard JSONSerialization.isValidJSONObject(envelope),
              let data = try? JSONSerialization.data(withJSONObject: envelope) else {
            return .requestPlain
        }
        return .requestCompositeData(bodyData: data, urlParameters: [:])
    }

    var headers: [String: String]? {
        var header = ["User-Agent": RupeeDeviceProbe.shared.userAgentTag()]
        if case .hubUploadImage = self {
            return header
        }
        header["Content-Type"] = "application/json"
        return header
    }

    private var payloadBody: [String: Any] {
        switch self {
        case .gateOTP(let p), .gateSignIn(let p), .gateSignOut(let p), .gateRetire(let p),
             .gateRegisterDevice(let p), .mintConfig(let p), .mintRelease(let p),
             .hubSnapshot(let p), .hubOffers(let p),
             .hubRecommendManual(let p), .hubRecommendAuto(let p),
             .hubOfferTerms(let p), .hubMember(let p),
             .hubAdjustSync(let p),
             .hubSubmitDeal(let p), .hubDeviceSync(let p), .hubContactSync(let p),
             .hubDealReady(let p), .hubFeedback(let p), .hubTrackEvent(let p),
             .ledgerRows(let p), .ledgerDetail(let p), .ledgerWithdraw(let p),
             .ledgerWithdrawInfo(let p), .ledgerRepayLink(let p), .ledgerExtend(let p),
             .verifyStages(let p), .verifyForm(let p), .verifyCommit(let p),
             .verifyFieldCommit(let p), .verifyLiveness(let p), .verifyIFSC(let p),
             .vaultCards(let p), .vaultEditCard(let p):
            return p
        case .hubUploadImage:
            return [:]
        }
    }

    /// TrustLoan-style routes: business fields live in `data`, sign uses base fields only.
    private var signPayloadBody: [String: Any] {
        switch self {
        case .ledgerRows, .gateRegisterDevice, .verifyIFSC, .vaultCards,
             .verifyStages, .hubFeedback, .hubRecommendManual, .hubRecommendAuto,
             .hubSnapshot, .hubMember:
            // Recommend / profile / list-style: business fields stay in data; sign = base fields only.
            return [:]
        case .hubAdjustSync:
            // Adjust adid upload — same path as profile, but sign never includes `adid`.
            return [:]
        case .ledgerDetail(let payload):
            let orderId = (payload["orderId"] as? String) ?? ""
            return ["orderId": orderId.isEmpty ? "1" : orderId]
        case .vaultEditCard(let payload):
            return [
                "accountType": payload["accountType"] ?? "",
                "bankCode": payload["bankCode"] ?? "",
                "accountNo": payload["accountNo"] ?? ""
            ]
        case .hubSubmitDeal(let payload):
            // All documented fields participate in sign (comma-joined multi values).
            return [
                "productIds": payload["productIds"] ?? "",
                "loanAmounts": payload["loanAmounts"] ?? "",
                "loanTerms": payload["loanTerms"] ?? "",
                "longitude": payload["longitude"] ?? "",
                "latitude": payload["latitude"] ?? "",
                "imei": payload["imei"] ?? "",
                "serialNo": payload["serialNo"] ?? ""
            ]
        case .hubDeviceSync(let payload), .hubContactSync(let payload), .hubDealReady(let payload):
            return ["orderId": payload["orderId"] ?? ""]
        case .ledgerRepayLink(let payload), .ledgerExtend(let payload):
            // LoanEase / Kiva: sign `orderId` only; `periodNoList` / payAccount stay in data.
            return ["orderId": payload["orderId"] ?? ""]
        case .ledgerWithdrawInfo(let payload), .ledgerWithdraw(let payload):
            // LoanEase: withdrawn/detail + apply/withdrawal sign `orderId` only
            // (`productId` / `loanAmount` / `loanTerm` stay in data).
            return ["orderId": payload["orderId"] ?? ""]
        case .verifyForm(let payload), .verifyCommit(let payload):
            // Kiva signs kycId only; commit item list stays in data outside the sign set.
            return ["kycId": payload["kycId"] ?? ""]
        case .verifyLiveness(let payload):
            // Kiva signs `liveness` only — do not include kycId in the sign pool.
            return ["liveness": payload["liveness"] ?? ""]
        default:
            return payloadBody
        }
    }

    /// Silent analytics and device-submit chain should not stack a second HUD on the mask.
    /// KYC commit/liveness HUDs are owned by `VerifyStagePilot` (system spinner on the form).
    /// Home `suphome` HUD is owned by `MintHubPilot.refreshHub` until UI apply finishes
    /// (route-level `onDispose` would hide before main-thread binding).
    var showsRequestHUD: Bool {
        switch self {
        case .hubTrackEvent, .hubAdjustSync, .hubDeviceSync, .hubContactSync, .hubDealReady,
             .hubRecommendManual, .hubRecommendAuto,
             .hubSnapshot,
             .verifyCommit, .verifyFieldCommit, .verifyLiveness:
            return false
        default:
            return true
        }
    }
}
