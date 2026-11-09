import Foundation
import RxSwift

final class CofferProfilePilot {
    let profile = FlexRelay<MintProfileShard?>(nil)
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()
    let signOutFailureSignal = FlexSignal<String>()
    let signedOut = FlexSignal<Void>()

    private let store = CofferProfileStore.shared
    private let gateStore = GateSessionStore.shared
    private let disposeBag = DisposeBag()
    private let refreshGate = SerialDisposable()

    func refresh() {
        isBusy.accept(true)
        let work = store.loadProfile()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] shard in
                self?.profile.accept(shard)
                self?.isBusy.accept(false)
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                guard !error.flex_isRequestCancelled else { return }
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? "Load failed")
            })
        refreshGate.disposable = work
    }

    func signOut() {
        isBusy.accept(true)
        gateStore.signOut()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                self?.isBusy.accept(false)
                self?.signedOut.accept(())
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                self?.signOutFailureSignal.accept((error as? PulseWireFault)?.message(or: FlexPhraseBook.Coffer.signOutFailed) ?? FlexPhraseBook.Coffer.signOutFailed)
            })
            .disposed(by: disposeBag)
    }
}
