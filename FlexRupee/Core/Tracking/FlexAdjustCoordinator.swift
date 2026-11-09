import Foundation
import AdjustSdk
import RxSwift

enum FlexAdjustCoordinator {
    
    private static let retryDelay: TimeInterval = 1
    private static let subscriptions = DisposeBag()
    private static var initialized = false

    static func initializeIfNeeded() {
        
        guard !initialized else { return }
        let token = (Bundle.main.object(forInfoDictionaryKey: "FlexAdjustAppToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty,
              let config = ADJConfig(appToken: token, environment: ADJEnvironmentProduction) else { return }
        Adjust.initSdk(config)
        initialized = true
    }
 
    static func syncAdidIfLoggedIn() {
        
        guard CofferVault.shared.isLoggedIn else { return }
        initializeIfNeeded()
        guard initialized else { return }
        readAdid { first in
            if let first {
                upload(first)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    readAdid { upload($0) }
                }
            }
        }
    }

    private static func readAdid(_ completion: @escaping (String?) -> Void) {
        Adjust.adid { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(trimmed.isEmpty ? nil : trimmed)
        }
    }

    /// Uploads Adjust `adid` only via dedicated `hubAdjustSync` (not profile `hubMember`).
    private static func upload(_ adid: String?) {
        guard CofferVault.shared.isLoggedIn else { return }
        guard let adid, !adid.isEmpty else { return }
        PulseWireHub.shared.dispatchVoid(.hubAdjustSync(payload: ["adid": adid]))
            .subscribe(onSuccess: { }, onError: { _ in })
            .disposed(by: subscriptions)
    }
}
