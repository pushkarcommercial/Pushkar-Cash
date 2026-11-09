import UIKit
import AdSupport
import AppTrackingTransparency
import Security

enum RupeeDeviceIdentityProbe {
    static func stableUUID() -> String {
        if let cached = keychainLoad(), !cached.isEmpty { return cached }
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
        guard !identifier.isEmpty else { return "" }
        keychainSave(identifier)
        return identifier
    }

    static func idfv() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }

    static func idfaOrNull() -> String {
        if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else {
                return RupeeDeviceConstants.nullToken
            }
            return ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }

    private static func keychainLoad() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RupeeDeviceConstants.keychainService,
            kSecAttrAccount as String: RupeeDeviceConstants.keychainService,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func keychainSave(_ value: String) {
        let data = value.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RupeeDeviceConstants.keychainService,
            kSecAttrAccount as String: RupeeDeviceConstants.keychainService
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
