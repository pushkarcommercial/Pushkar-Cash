import Foundation
import Moya

final class MintStampBuilder {
    static let shared = MintStampBuilder()

    private let appSlug = "pushkarcash"
    private let channelTag = "app_store"
    private let protocolVersion = "2.0"
    private let signPepper = "N45i6Lj73Qd1NNO4"

    private init() {}

    func rejectH5SessionBag(mobile: String?) -> [String: Any] {
        let vault = CofferVault.shared
        return [
            "appId": appSlug,
            "salt": signPepper,
            "mobile": mobile ?? vault.cachedMobileLine,
            "baseUrl": FlexServiceEndpoint.baseURL.absoluteString,
            "userId": vault.memberId,
            "token": vault.bearerToken,
            "UA": RupeeDeviceProbe.shared.userAgentTag(appSlug: appSlug),
            "deviceId": RupeeDeviceProbe.shared.deviceFingerprint,
            "clientVersion": RupeeDeviceProbe.shared.buildStamp
        ]
    }

    func weaveEnvelope(dataPayload: [String: Any], signPayload: [String: Any]? = nil) -> [String: Any] {
        let nonce = randomNonce()
        let clientTime = "\(Int(Date().timeIntervalSince1970 * 1000))"
        var envelope = baseFields(nonce: nonce, clientTime: clientTime)
        envelope["data"] = stringifyPayload(dataPayload)
        let sign = forgeSignature(nonce: nonce, dataPayload: signPayload ?? dataPayload)
        envelope["sign"] = sign
        return envelope
    }

    private func baseFields(nonce: String, clientTime: String) -> [String: Any] {
        var envelope: [String: Any] = [
            "nonce": nonce,
            "deviceId": RupeeDeviceProbe.shared.deviceFingerprint,
            "clientVersion": RupeeDeviceProbe.shared.buildStamp,
            "appId": appSlug,
            "os": "2",
            "clientTime": clientTime,
            "channel": channelTag,
            "version": protocolVersion,
            "clientLanguage": "en"
        ]
        let vault = CofferVault.shared
        if !vault.bearerToken.isEmpty { envelope["token"] = vault.bearerToken }
        if !vault.memberId.isEmpty { envelope["userId"] = vault.memberId }
        return envelope
    }

    /// Flatten leaf scalars to strings; keep nested dict/array shape
    /// (order `check`, contact `list`, etc.) — matches Kiva/TrustLoan/FinTrust.
    private func stringifyPayload(_ payload: [String: Any]) -> [String: Any] {
        var boxed: [String: Any] = [:]
        payload.forEach { key, value in
            boxed[key] = normalizeDataValue(value)
        }
        return boxed
    }

    private func normalizeDataValue(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var nested: [String: Any] = [:]
            dict.forEach { nested[$0.key] = normalizeDataValue($0.value) }
            return nested
        }
        
        // Swift generics: [String: String] / [[String: String]] do not cast to Any variants.
        if let dict = value as? [String: String] {
            return dict
        }
        
        if let rows = value as? [[String: String]] {
            return rows
        }
        
        if let rows = value as? [[String: Any]] {
            return rows.map { row -> [String: Any] in
                var nested: [String: Any] = [:]
                row.forEach { nested[$0.key] = normalizeDataValue($0.value) }
                return nested
            }
        }
        if let list = value as? [Any] {
            return list.map { normalizeDataValue($0) }
        }
        return stringify(value)
    }

    private func forgeSignature(nonce: String, dataPayload: [String: Any]) -> String {
        var signPool: [String: String] = [
            "appId": appSlug,
            "deviceId": RupeeDeviceProbe.shared.deviceFingerprint,
            "channel": channelTag,
            "nonce": nonce,
            "version": protocolVersion
        ]
        dataPayload.forEach { key, value in
            // Sign pool is flat strings only — nested values must not enter the sign set
            // (submit signs baseline fields only via MintRoute.signPayloadBody).
            if value is [String: Any] || value is [Any] { return }
            signPool[key] = stringify(value)
        }
        let joined = signPool.values.sorted(by: >).joined(separator: "*") + "MD" + signPepper
        return joined.flexMD5Upper()
    }

    private func stringify(_ value: Any) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private func randomNonce() -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in alphabet.randomElement()! })
    }

    func weaveUploadMultipart(jpegData: Data, fileName: String) -> [MultipartFormData] {
        let envelope = weaveEnvelope(dataPayload: [:])
        var parts: [MultipartFormData] = []
        envelope.sorted { $0.key < $1.key }.forEach { key, value in
            let text: String
            if key == "data", let payload = value as? [String: Any],
               let json = try? JSONSerialization.data(withJSONObject: payload),
               let encoded = String(data: json, encoding: .utf8) {
                text = encoded
            } else {
                text = stringify(value)
            }
            guard let field = text.data(using: .utf8) else { return }
            parts.append(MultipartFormData(provider: .data(field), name: key))
        }
        parts.append(MultipartFormData(provider: .data(jpegData),
                                       name: "file",
                                       fileName: fileName,
                                       mimeType: "image/jpeg"))
        return parts
    }
}
