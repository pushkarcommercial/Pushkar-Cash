import Foundation
import Network
import CFNetwork
import CoreTelephony
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

enum RupeeDeviceNetworkProbe {
    struct TelephonyInfo {
        let primary: String
        let secondary: String
        let slotCount: String
        let simCount: String
    }

    private static let wifiLock = NSLock()
    private static var cachedSSID: String?
    private static var cachedBSSID: String?

    /// LoanEase parity: prefer `NEHotspotNetwork.fetchCurrent` (async); CaptiveNetwork below iOS 14.
    static func fetchCurrentWiFiInfo(completion: @escaping (_ ssid: String?, _ bssid: String?) -> Void) {
        if #available(iOS 14.0, *) {
            NEHotspotNetwork.fetchCurrent { network in
                let ssid = network?.ssid
                let bssid = network?.bssid
                wifiLock.lock()
                cachedSSID = ssid
                cachedBSSID = bssid
                wifiLock.unlock()
                DispatchQueue.main.async { completion(ssid, bssid) }
            }
            return
        }
        let captive = legacyCaptiveWiFi()
        wifiLock.lock()
        cachedSSID = captive.ssid
        cachedBSSID = captive.bssid
        wifiLock.unlock()
        DispatchQueue.main.async { completion(captive.ssid, captive.bssid) }
    }

    /// Cached / sync fallback for callers that cannot wait (prefer `fetchCurrentWiFiInfo`).
    static func currentWiFiInfo() -> (ssid: String?, bssid: String?) {
        wifiLock.lock()
        let ssid = cachedSSID
        let bssid = cachedBSSID
        wifiLock.unlock()
        if nonEmpty(ssid) != nil || nonEmpty(bssid) != nil {
            return (ssid, bssid)
        }
        return legacyCaptiveWiFi()
    }

    /// Refresh Wi‑Fi cache before device report.
    static func refreshWiFiCache(completion: @escaping () -> Void) {
        fetchCurrentWiFiInfo { _, _ in
            completion()
        }
    }

    /// LoanEase `wifiName(from:)` — empty / `"0"` → `null`.
    static func wifiName(from ssid: String?) -> String {
        let raw = (ssid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "0" { return RupeeDeviceConstants.nullToken }
        return raw
    }

    /// LoanEase `wifiSsid` — raw SSID, empty → `null` (does not treat `"0"` as null).
    static func wifiSsidValue(from ssid: String?) -> String {
        let raw = ssid ?? ""
        return raw.isEmpty ? RupeeDeviceConstants.nullToken : raw
    }

    static func networkCategory() -> String {
        let sema = DispatchSemaphore(value: 0)
        var result = "-99"

        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "flex.rupee.net.probe")
        monitor.pathUpdateHandler = { path in
            defer {
                sema.signal()
                monitor.cancel()
            }
            guard path.status == .satisfied else { return }
            if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                result = "1"
                return
            }
            let cellular = CTTelephonyNetworkInfo()
            let technology = cellular.serviceCurrentRadioAccessTechnology?.values.first
                ?? cellular.currentRadioAccessTechnology
            result = radioLabel(for: technology)
        }
        monitor.start(queue: queue)
        _ = sema.wait(timeout: .now() + 1.0)
        return result
    }

    static func telephonyOperators() -> TelephonyInfo {
        let info = CTTelephonyNetworkInfo()
        let providers = info.serviceSubscriberCellularProviders ?? [:]
        let carriers = providers.values.compactMap(\.carrierName).filter { !$0.isEmpty }
        let primary = carriers.first ?? RupeeDeviceConstants.nullToken
        let secondary = carriers.count > 1 ? carriers[1] : RupeeDeviceConstants.nullToken
        return TelephonyInfo(
            primary: primary,
            secondary: secondary,
            slotCount: "\(max(providers.count, 1))",
            simCount: "\(carriers.count)"
        )
    }

    static func isSystemProxyEnabled() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let url = URL(string: "https://www.apple.com") else {
            return false
        }
        let proxies = CFNetworkCopyProxiesForURL(url as CFURL, proxySettings as CFDictionary)
            .takeRetainedValue() as? [[String: Any]]
        guard let first = proxies?.first else { return false }
        let proxyType = first[kCFProxyTypeKey as String] as? String
        return proxyType != (kCFProxyTypeNone as String)
    }

    static func isVPNOn() -> Bool {
        if vpnViaProxyScoped() { return true }
        return vpnViaPathInterfaces()
    }

    // MARK: - Private

    private static func legacyCaptiveWiFi() -> (ssid: String?, bssid: String?) {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return (nil, nil) }
        for iface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(iface as CFString) as? [String: Any] else { continue }
            let ssid = (info[kCNNetworkInfoKeySSID as String] as? String) ?? (info["SSID"] as? String)
            let bssid = (info[kCNNetworkInfoKeyBSSID as String] as? String) ?? (info["BSSID"] as? String)
            if nonEmpty(ssid) != nil || nonEmpty(bssid) != nil {
                return (ssid, bssid)
            }
        }
        return (nil, nil)
    }

    private static func radioLabel(for technology: String?) -> String {
        guard let technology else { return "-99" }
        switch technology {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
            return "5"
        case CTRadioAccessTechnologyLTE:
            return "4"
        case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyGPRS:
            return "2"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return "3"
        default:
            return "-99"
        }
    }

    private static func vpnViaProxyScoped() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = proxySettings["__SCOPED__"] as? [String: Any] else {
            return false
        }
        return scoped.keys.contains { key in
            let lowered = String(describing: key).lowercased()
            return ["tap", "tun", "ppp", "ipsec"].contains { lowered.contains($0) }
        }
    }

    private static func vpnViaPathInterfaces() -> Bool {
        let sema = DispatchSemaphore(value: 0)
        var active = false
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "flex.rupee.vpn.probe")
        monitor.pathUpdateHandler = { path in
            active = path.availableInterfaces.contains { iface in
                let name = iface.name.lowercased()
                return name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            }
            sema.signal()
            monitor.cancel()
        }
        monitor.start(queue: queue)
        _ = sema.wait(timeout: .now() + 1.0)
        return active
    }

    private static func nonEmpty(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty, raw != "null" else { return nil }
        return raw
    }
}
