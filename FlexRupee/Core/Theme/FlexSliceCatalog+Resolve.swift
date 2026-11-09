import Foundation

extension FlexSliceCatalog {
    static func orderStatusArt(for state: Int) -> String {
        switch state {
        case 10: return statusReviewPearl
        case 15: return statusRejectClay
        case 20: return statusFlowTeal
        case 30: return statusReviewPearl
        case 32: return statusWithdrawBloom
        case 40: return statusPendingAmber
        case 50: return statusOverdueRose
        case 60: return statusPendingAmber
        case 61: return statusOverdueRose
        case 70: return statusPayoffSage
        case 71: return statusChangeVine
        default: return statusDraftMist
        }
    }

    static func kycStageArt(for kind: String) -> String {
        switch kind {
        case "liveness": return kycFacePrism
        case "identity", "tax": return kycCardTemplate
        case "urgent_contact": return kycEmergencyLeaf
        case "pay_account": return loanBankChip
        case "personal", "work", "questionnaire": return kycCameraOrb
        default: return kycCameraOrb
        }
    }
}
