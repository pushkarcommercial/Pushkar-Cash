import Foundation
import ObjectMapper
import RxSwift

enum FlexReleaseCoordinator {
    private static let disposeBag = DisposeBag()
    private static var isChecking = false

    /// Checks version policy (P37). Completion receives `true` when a force-upgrade overlay is shown.
    static func auditOnLaunch(completion: ((Bool) -> Void)? = nil) {
        guard !isChecking else {
            completion?(false)
            return
        }
        isChecking = true
        FlexReleaseStore.shared.fetchReleaseNote()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { note in
                isChecking = false
                let forced = evaluate(note, fromServerFault: false)
                completion?(forced)
            }, onError: { _ in
                isChecking = false
                completion?(false)
            })
            .disposed(by: disposeBag)
    }

    static func handleVersionFault() {
        FlexReleaseStore.shared.fetchReleaseNote()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { note in
                evaluate(note, fromServerFault: true)
            }, onError: { _ in
                presentFallbackForceUpgrade()
            })
            .disposed(by: disposeBag)
    }

    @discardableResult
    private static func evaluate(_ note: ReleaseNoteShard, fromServerFault: Bool) -> Bool {
        let current = RupeeDeviceProbe.shared.buildStamp
        let forceFloor = note.forceBuild ?? ""
        let latest = note.latestBuild ?? ""

        if !forceFloor.isEmpty, FlexVersionLexicon.isBelow(current, minimum: forceFloor) {
            showUpgrade(note: note, force: true)
            return true
        }
        if fromServerFault {
            showUpgrade(note: note, force: true)
            return true
        }
        if !latest.isEmpty, FlexVersionLexicon.isBelow(current, minimum: latest) {
            showUpgrade(note: note, force: false)
        }
        return false
    }

    private static func showUpgrade(note: ReleaseNoteShard, force: Bool) {
        guard let host = FlexRootOrchestrator.shared.keyWindow else { return }
        FlexUpgradeOverlay.present(on: host, note: note, force: force)
    }

    private static func presentFallbackForceUpgrade() {
        let stub = ReleaseNoteShard(map: Map(mappingType: .fromJSON, JSON: [:]))!
        guard let host = FlexRootOrchestrator.shared.keyWindow else { return }
        FlexUpgradeOverlay.present(on: host, note: stub, force: true)
    }

    static func recordAppLaunch() {
        CofferVault.shared.appLaunchCount += 1
    }
}
