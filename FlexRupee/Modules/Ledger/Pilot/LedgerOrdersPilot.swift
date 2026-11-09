import Foundation
import RxSwift

enum LedgerTabKind: Int, CaseIterable {
    case pendingRepay = 0
    case submit = 1
    case processing = 2
    case completed = 3

    /// API filter: Pending Repayment=20, Submit Application=10, Processing=30, Completed=40
    var orderStatusFilter: Int {
        switch self {
        case .pendingRepay: return 20
        case .submit: return 10
        case .processing: return 30
        case .completed: return 40
        }
    }

    var title: String {
        switch self {
        case .pendingRepay: return "Pending\nRepayment"
        case .submit: return "Submit\nApplication"
        case .processing: return "Processing"
        case .completed: return "Completed"
        }
    }
}

final class LedgerOrdersPilot {
    let activeTab = FlexRelay(LedgerTabKind.pendingRepay)
    let rows = FlexRelay<[LedgerRowShard]>([])
    let isBusy = FlexRelay(false)
    let toastSignal = FlexSignal<String>()

    private let store = LedgerOrderStore.shared
    private let disposeBag = DisposeBag()
    private let fetchGate = SerialDisposable()

    init() {
        activeTab.stream.skip(1).subscribe(onNext: { [weak self] tab in
            self?.loadRows(for: tab)
        }).disposed(by: disposeBag)
    }

    func loadRows(for tab: LedgerTabKind? = nil) {
        let filter = (tab ?? activeTab.value).orderStatusFilter
        isBusy.accept(true)
        let work = store.fetchRows(filter: filter)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] list in
                self?.rows.accept(list)
                self?.isBusy.accept(false)
            }, onError: { [weak self] error in
                self?.isBusy.accept(false)
                // Tab reappear replaces the in-flight fetch — don't toast cancellation.
                guard !error.flex_isRequestCancelled else { return }
                self?.rows.accept([])
                self?.toastSignal.accept((error as? PulseWireFault)?.description ?? "Load failed")
            })
        fetchGate.disposable = work
    }

    func selectTab(_ tab: LedgerTabKind) {
        guard activeTab.value != tab else {
            loadRows(for: tab)
            return
        }
        activeTab.accept(tab)
    }
}

enum LedgerOrdersLaunch {
    static var pendingTab: LedgerTabKind?
}
