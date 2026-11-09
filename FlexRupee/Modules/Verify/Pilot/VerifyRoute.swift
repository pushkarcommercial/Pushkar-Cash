import UIKit

/// Where KYC was entered — drives exit navigation.
enum VerifyEntrySource {
    /// Home Apply / hub KYC banner.
    case hub
    /// Calculator EMI detail Apply Now.
    case emiDetail
}

enum VerifyRoute {
    struct StageRoute {
        let kind: String
        let title: String
        let factory: () -> VerifyFormCanvas
    }

    static let ordered: [StageRoute] = [
        StageRoute(kind: "personal", title: "Personal Information", factory: { VerifyPersonalCanvas() }),
        StageRoute(kind: "work", title: "Work information", factory: { VerifyWorkCanvas() }),
        StageRoute(kind: "questionnaire", title: "Credit standing", factory: { VerifyCreditCanvas() }),
        StageRoute(kind: "liveness", title: "Face identification", factory: { VerifyFaceCanvas() }),
        StageRoute(kind: "identity", title: "Aadhaar", factory: { VerifyAadhaarCanvas() }),
        StageRoute(kind: "tax", title: "PAN", factory: { VerifyPanCanvas() }),
        StageRoute(kind: "pay_account", title: "Bank Account", factory: { VerifyBankCanvas() }),
        StageRoute(kind: "urgent_contact", title: "Emergency Contact", factory: { VerifyEmergencyCanvas() })
    ]

    static func stage(from stages: [VerifyStageShard], kind: String) -> VerifyStageShard? {
        stages.first { $0.stageKind == kind || $0.stageId == kind }
    }

    static func isComplete(_ stage: VerifyStageShard?) -> Bool {
        (stage?.stageState ?? 0) == 1
    }

    static func firstIncomplete(in stages: [VerifyStageShard]) -> (StageRoute, VerifyStageShard)? {
        for route in ordered {
            guard let stage = stage(from: stages, kind: route.kind), !isComplete(stage) else { continue }
            return (route, stage)
        }
        return nil
    }

    static func nextIncomplete(after kind: String, in stages: [VerifyStageShard]) -> (StageRoute, VerifyStageShard)? {
        guard let start = ordered.firstIndex(where: { $0.kind == kind }) else { return nil }
        for route in ordered.dropFirst(start + 1) {
            guard let stage = stage(from: stages, kind: route.kind), !isComplete(stage) else { continue }
            return (route, stage)
        }
        return nil
    }

    static func pushFirstIncomplete(from host: UIViewController,
                                    stages: [VerifyStageShard],
                                    entrySource: VerifyEntrySource = .hub,
                                    reload: Bool = false) {
        guard let (route, stage) = firstIncomplete(in: stages) else {
            // Empty list or every stage finished — avoid silent no-op on Apply Now.
            FlexToast.show(stages.isEmpty ? FlexPhraseBook.Verify.stagesUnavailable : FlexPhraseBook.Hub.applyPrompt, on: host.view)
            return
        }
        let canvas = route.factory()
        // Pass kycId (stageId) for /kyc/init — same string as "personal"/"work"/…
        canvas.configure(stageId: stage.stageId,
                         stageKind: route.kind,
                         title: route.title,
                         stages: stages,
                         entrySource: entrySource)
        host.navigationController?.pushViewController(canvas, animated: true)
    }

    static func chainNext(from host: VerifyFormCanvas, completedKind: String, stages: [VerifyStageShard]) {
        guard let (route, stage) = nextIncomplete(after: completedKind, in: stages) else {
            finishAllStages(from: host)
            return
        }
        let canvas = route.factory()
        canvas.configure(stageId: stage.stageId,
                         stageKind: route.kind,
                         title: route.title,
                         stages: stages,
                         entrySource: host.entrySource)
        var stack = host.navigationController?.viewControllers ?? []
        if let index = stack.firstIndex(where: { $0 === host }) {
            stack.remove(at: index)
        }
        stack.append(canvas)
        host.navigationController?.setViewControllers(stack, animated: true)
    }

    /// All KYC stages done → always return home and refresh.
    static func finishAllStages(from host: VerifyFormCanvas) {
        NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
        switch host.entrySource {
        case .hub:
            host.navigationController?.popToRootViewController(animated: true)
        case .emiDetail:
            // Leave EMI detail under the calc tab, then switch to home.
            if let nav = host.navigationController {
                if let detail = nav.viewControllers.first(where: { $0 is RupeeEMIResultCanvas }) {
                    nav.popToViewController(detail, animated: false)
                } else {
                    nav.popToRootViewController(animated: false)
                }
            }
            FlexRootOrchestrator.shared.popToHub()
        }
    }

    /// Mid-flow back / abandon — EMI entry returns to calculator detail; hub entry to home root.
    static func abandonFlow(from host: VerifyFormCanvas) {
        switch host.entrySource {
        case .hub:
            host.navigationController?.popToRootViewController(animated: true)
        case .emiDetail:
            if let nav = host.navigationController,
               let detail = nav.viewControllers.first(where: { $0 is RupeeEMIResultCanvas }) {
                nav.popToViewController(detail, animated: true)
            } else {
                host.navigationController?.popViewController(animated: true)
            }
        }
    }
}
