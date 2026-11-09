import Foundation
import Network
import AppTrackingTransparency
import UIKit
import RxSwift

extension Notification.Name {
    static let flexNetworkDidBecomeReady = Notification.Name("flex.network.didBecomeReady")
}

/// Network reachability — mirrors TrustLoan `TrustLoanNetworkManager.isNetworkReachable` + first-install notify.
enum FlexNetworkWatch {
    private static let queue = DispatchQueue(label: "flex.network.watch")
    private static let stateLock = NSLock()
    private static var monitor: NWPathMonitor?
    private static var started = false
    private static var didPostReady = false
    private static var pathSatisfied = false

    /// True once path has been `.satisfied` at least once this process (survives probe races).
    static var hasBecomeReady: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return didPostReady
    }

    static func start() {
        guard !started else { return }
        started = true
        let pathMonitor = NWPathMonitor()
        monitor = pathMonitor
        pathMonitor.pathUpdateHandler = { path in
            let ok = path.status == .satisfied
            stateLock.lock()
            pathSatisfied = ok
            stateLock.unlock()
            guard ok else { return }
            postReadyOnce()
        }
        pathMonitor.start(queue: queue)
        if pathMonitor.currentPath.status == .satisfied {
            stateLock.lock()
            pathSatisfied = true
            stateLock.unlock()
            postReadyOnce()
        }
    }

    static func isReachable() -> Bool {
        stateLock.lock()
        let cached = pathSatisfied || didPostReady
        stateLock.unlock()
        if cached { return true }
        guard let monitor else { return false }
        return monitor.currentPath.status == .satisfied
    }

    static func isFirstInstallLaunch() -> Bool {
        CofferVault.shared.appLaunchCount <= 1
    }

    private static func postReadyOnce() {
        stateLock.lock()
        guard !didPostReady else {
            stateLock.unlock()
            return
        }
        didPostReady = true
        stateLock.unlock()
        DispatchQueue.main.async {
            PulseBeaconRecorder.shared.stampLaunchAfterNetworkReady()
            NotificationCenter.default.post(name: .flexNetworkDidBecomeReady, object: nil)
        }
    }
}

/// ATT / IDFA — mirrors TrustLoan `TrustLoanDeviceManager.requestTrackingAuthorizationIfNeeded`.
enum FlexTrackingGate {
    private static var isScheduling = false
    private static var didStampIDFASession = false

    static func requestAuthorizationIfNeeded(completion: (() -> Void)? = nil) {
        guard #available(iOS 14, *) else {
            PulseBeaconRecorder.shared.stamp(.idfaGranted)
            completion?()
            return
        }
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized, .denied, .restricted:
            // Already answered — one-shot status stamp for this session.
            stampIDFAStatusIfNeeded(ATTrackingManager.trackingAuthorizationStatus)
            completion?()
            return
        case .notDetermined:
            guard !isScheduling else {
                completion?()
                return
            }
            isScheduling = true
            DispatchQueue.main.async {
                presentIfEligible(retry: 0, completion: completion)
            }
        @unknown default:
            completion?()
        }
    }

    @available(iOS 14, *)
    private static func stampIDFAStatusIfNeeded(_ status: ATTrackingManager.AuthorizationStatus) {
        guard !didStampIDFASession else { return }
        didStampIDFASession = true
        switch status {
        case .authorized:
            PulseBeaconRecorder.shared.stamp(.idfaGranted)
        default:
            PulseBeaconRecorder.shared.stamp(.idfaDenied)
        }
    }

    @available(iOS 14, *)
    private static func presentIfEligible(retry: Int, completion: (() -> Void)?) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            isScheduling = false
            stampIDFAStatusIfNeeded(ATTrackingManager.trackingAuthorizationStatus)
            completion?()
            return
        }
        guard UIApplication.shared.applicationState == .active,
              FlexRootOrchestrator.shared.keyWindow != nil else {
            guard retry < 20 else {
                isScheduling = false
                completion?()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                presentIfEligible(retry: retry + 1, completion: completion)
            }
            return
        }
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                stampIDFAStatusIfNeeded(status)
                isScheduling = false
                completion?()
            }
        }
    }
}

/// Home bootstrap: network → config → IDFA → version audit → hub refresh (TrustLoan `loadHomeBusiness` order).
enum FlexHubBootstrap {
    private static var didLoadConfig = false
    private static let disposeBag = DisposeBag()

    static func runOnHome(whenReady: @escaping () -> Void) {
        FlexNetworkWatch.start()
        afterNetworkReady {
            fetchConfigIfNeeded {
                FlexTrackingGate.requestAuthorizationIfNeeded {
                    FlexReleaseCoordinator.auditOnLaunch { _ in
                        whenReady()
                    }
                }
            }
        }
    }

    /// Login / gate screen — config only after network is ready (TrustLoan `loadConfigData`).
    static func runConfigWhenNetworkReady(_ action: @escaping () -> Void) {
        FlexNetworkWatch.start()
        afterNetworkReady {
            guard !didLoadConfig else { return }
            didLoadConfig = true
            action()
        }
    }

    static func resetConfigGateForRetry() {
        didLoadConfig = false
    }

    private static func afterNetworkReady(_ action: @escaping () -> Void) {
        final class OnceBox {
            private let lock = NSLock()
            private var done = false
            func fire(_ work: @escaping () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !done else { return }
                done = true
                DispatchQueue.main.async(execute: work)
            }
        }
        let once = OnceBox()
        // Already had network this process, or path is satisfied now.
        if FlexNetworkWatch.hasBecomeReady || FlexNetworkWatch.isReachable() {
            once.fire(action)
            return
        }
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: .flexNetworkDidBecomeReady,
            object: nil,
            queue: .main
        ) { _ in
            if let token { NotificationCenter.default.removeObserver(token) }
            once.fire(action)
        }
        // Close the race: ready may fire between the first check and observer registration.
        if FlexNetworkWatch.hasBecomeReady || FlexNetworkWatch.isReachable() {
            if let token { NotificationCenter.default.removeObserver(token) }
            once.fire(action)
        }
    }

    private static func fetchConfigIfNeeded(then: @escaping () -> Void) {
        didLoadConfig = true
        GateSessionStore.shared.fetchMintConfig()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { _ in then() }, onError: { _ in then() })
            .disposed(by: disposeBag)
    }
}
