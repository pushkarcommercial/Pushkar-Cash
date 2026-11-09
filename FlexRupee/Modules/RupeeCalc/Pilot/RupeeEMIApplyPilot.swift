import UIKit
import Foundation
import RxSwift

/// Apply-button visibility and routing on EMI result — aligned with TrustLoan result page.
final class RupeeEMIApplyPilot {
    let showApply = FlexRelay(false)
    let isBusy = FlexRelay(false)

    private let store = MintHubStore.shared
    private let disposeBag = DisposeBag()

    func refreshApplyVisibility() {
        guard FlexLoginGate.isLoggedIn else {
            showApply.accept(false)
            return
        }
        store.loadSnapshot()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] snap in
                let state = snap.memberState ?? 0
                self?.showApply.accept(state == HubMemberPhase.verifyPending.rawValue
                                      || state == HubMemberPhase.creditReady.rawValue)
            }, onError: { [weak self] _ in
                self?.showApply.accept(false)
            })
            .disposed(by: disposeBag)
    }

    func performApply(from host: UIViewController,
                      onVerify: @escaping ([VerifyStageShard]) -> Void,
                      onGoHome: @escaping () -> Void) {
        guard FlexLoginGate.requireLogin(from: host) else { return }
        isBusy.accept(true)
        Single.zip(store.loadSnapshot(), store.loadVerifyStages())
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { snap, stages in
                self.isBusy.accept(false)
                let state = snap.memberState ?? 0
                let incomplete = stages.filter { ($0.stageState ?? 0) == 0 }
                if state == HubMemberPhase.verifyPending.rawValue || !incomplete.isEmpty {
                    onVerify(incomplete.isEmpty ? stages : incomplete)
                    return
                }
                if state == HubMemberPhase.creditReady.rawValue {
                    onGoHome()
                }
            }, onError: { [weak self] _ in
                self?.isBusy.accept(false)
                FlexToast.show(FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }
}
