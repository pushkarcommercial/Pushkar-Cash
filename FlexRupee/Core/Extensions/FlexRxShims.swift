import Foundation
import Moya
import RxSwift

extension Error {
    /// True when a SerialDisposable / tab re-entry cancelled an in-flight Moya request.
    var flex_isRequestCancelled: Bool {
        if let moya = self as? MoyaError {
            switch moya {
            case .underlying(let underlying, _):
                return underlying.flex_isRequestCancelled
            default:
                return false
            }
        }
        let ns = self as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}

final class FlexRelay<T> {
    private let subject: BehaviorSubject<T>
    private(set) var value: T

    init(_ value: T) {
        self.value = value
        subject = BehaviorSubject(value: value)
    }

    func accept(_ value: T) {
        self.value = value
        subject.onNext(value)
    }

    var stream: Observable<T> {
        subject.asObservable()
    }
}

final class FlexSignal<T> {
    private let subject = PublishSubject<T>()

    func accept(_ value: T) {
        subject.onNext(value)
    }

    var stream: Observable<T> {
        subject.asObservable()
    }
}
