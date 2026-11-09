import Foundation
import Alamofire
import Moya
import RxSwift
import ObjectMapper
import Result

enum PulseWireFault: Error {
    case transport(String)
    case decode
    case business(code: Int, message: String)
    case sessionExpired
    case versionBlocked

    /// Unknown business codes need a screen-specific explanation, not a network error.
    func message(or fallback: String) -> String {
        if case .business(_, let message) = self,
           (message == FlexPhraseBook.Network.businessRejected || message == FlexPhraseBook.Network.busy || message == "Request failed") {
            return fallback
        }
        return description
    }

    /// ID / tax photo unclear — only these codes show the auth error sheet; others toast backend copy.
    static let unclearDocumentCodes: Set<Int> = [6212011, 6212201]

    static func isUnclearDocument(_ error: Error) -> Bool {
        guard let fault = error as? PulseWireFault,
              case .business(let code, _) = fault else { return false }
        return unclearDocumentCodes.contains(code)
    }

    /// Prefer API `resultMsg`; fall back only when the server left it empty.
    static func backendCopy(from error: Error, fallback: String) -> String {
        guard let fault = error as? PulseWireFault else { return fallback }
        if case .business(_, let message) = fault {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        return fault.description
    }
}

final class PulseWireHub {
    static let shared = PulseWireHub()

    private let provider: MoyaProvider<MintRoute>
    private static let requestTimeout: TimeInterval = 30

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.requestTimeout
        let manager = Manager(configuration: configuration)
        manager.startRequestsImmediately = false
        provider = MoyaProvider<MintRoute>(manager: manager, plugins: [])
    }

    func dispatch<T: WireEnvelope>(_ route: MintRoute, as type: T.Type) -> Single<T> {
        trackHUD(for: route, work: performRequest(route) { [weak self] response in
            guard let self else { throw PulseWireFault.transport("Hub unavailable") }
            let envelope = try self.parseEnvelope(response, as: type)
            try self.guardBusinessRules(envelope)
            return envelope
        })
    }

    func dispatchVoid(_ route: MintRoute) -> Single<Void> {
        dispatch(route, as: EmptyWireEnvelope.self).map { _ in () }
    }

    /// Returns envelope even when `resultCode` is a business error (except session/version faults).
    func dispatchLenient<T: WireEnvelope>(_ route: MintRoute, as type: T.Type) -> Single<T> {
        trackHUD(for: route, work: performRequest(route) { [weak self] response in
            guard let self else { throw PulseWireFault.transport("Hub unavailable") }
            let envelope = try self.parseEnvelope(response, as: type)
            try self.guardSessionOnly(envelope)
            return envelope
        })
    }

    /// Pairs HUD show/hide with the Rx subscription lifecycle so success, failure, and cancel all dismiss.
    private func trackHUD<T>(for route: MintRoute, work: Single<T>) -> Single<T> {
        guard route.showsRequestHUD else { return work }
        return work.do(onSubscribe: { FlexSpinnerOverlay.beginRequest() },
                       onDispose: { FlexSpinnerOverlay.endRequest() })
    }

    private func performRequest<T>(_ route: MintRoute,
                                   map: @escaping (Response) throws -> T) -> Single<T> {
        Single.create { [weak self] observer -> Disposable in
            guard let self else {
                observer(.error(PulseWireFault.transport("Hub unavailable")))
                return Disposables.create()
            }
            let token = self.provider.request(route) { networkResult in
                do {
                    let response = try networkResult.dematerialize()
                    let value = try map(response)
                    observer(.success(value))
                } catch {
                    observer(.error(error))
                }
            }
            return Disposables.create { token.cancel() }
        }
    }

    private func guardSessionOnly(_ envelope: WireEnvelope) throws {
        guard let code = envelope.pulseCode else { return }
        switch code {
        case 200:
            return
        case 2000001, 2000002, 2002001:
            DispatchQueue.main.async {
                CofferVault.shared.wipeSession()
                FlexRootOrchestrator.shared.presentGate(replaceRoot: true)
            }
            throw PulseWireFault.sessionExpired
        case 2009006:
            DispatchQueue.main.async {
                FlexReleaseCoordinator.handleVersionFault()
            }
            throw PulseWireFault.versionBlocked
        default:
            return
        }
    }

    private func parseEnvelope<T: WireEnvelope>(_ response: Response, as type: T.Type) throws -> T {
        guard response.statusCode == 200 else {
            throw PulseWireFault.transport("HTTP \(response.statusCode)")
        }
        guard let json = String(data: response.data, encoding: .utf8),
              let model = Mapper<T>().map(JSONString: json) else {
            throw PulseWireFault.decode
        }
        return model
    }

    private func guardBusinessRules(_ envelope: WireEnvelope) throws {
        guard let code = envelope.pulseCode else { return }
        switch code {
        case 200:
            return
        case 2000001, 2000002, 2002001:
            DispatchQueue.main.async {
                CofferVault.shared.wipeSession()
                FlexRootOrchestrator.shared.presentGate(replaceRoot: true)
            }
            throw PulseWireFault.sessionExpired
        case 2009006:
            DispatchQueue.main.async {
                FlexReleaseCoordinator.handleVersionFault()
            }
            throw PulseWireFault.versionBlocked
        default:
            throw PulseWireFault.business(code: code, message: envelope.businessMessage)
        }
    }
}
