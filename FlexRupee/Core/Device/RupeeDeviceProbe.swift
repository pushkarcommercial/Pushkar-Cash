import UIKit

/// Aggregates modular device probes into the `/mobile/device` & `/mobile/registerDevice` field set.
final class RupeeDeviceProbe {
    static let shared = RupeeDeviceProbe()

    private init() {}

    var deviceFingerprint: String {
        RupeeDeviceIdentityProbe.stableUUID()
    }

    var buildStamp: String {
        RupeeDeviceHardwareProbe.appVersionShortString()
    }

    var hardwareLabel: String {
        RupeeDeviceHardwareProbe.hardwareModelIdentifier()
    }

    var osStamp: String {
        UIDevice.current.systemVersion
    }

    /// `{appId}/{version}(Apple;Mobile;{marketingName};iOS {systemVersion};)` —
    /// marketing name (e.g. iPhone XR), not hw.machine (iPhone11,8).
    func userAgentTag(appSlug: String = "pushkarcash") -> String {
        let model = RupeeDeviceHardwareProbe.deviceModelName()
        return "\(appSlug)/\(buildStamp)(Apple;Mobile;\(model);iOS \(osStamp);)"
    }

    /// Sync snapshot (may miss Wi‑Fi on iOS 14+). Prefer `buildSyncPayload`.
    func syncPayload() -> [String: Any] {
        buildFieldMap()
    }

    /// Refresh Wi‑Fi first (LoanEase `fetchCurrentWiFiInfo`), then assemble the report body.
    func buildSyncPayload(completion: @escaping ([String: Any]) -> Void) {
        RupeeDeviceNetworkProbe.fetchCurrentWiFiInfo { [weak self] ssid, bssid in
            guard let self else {
                completion([:])
                return
            }
            completion(self.buildFieldMap(wifiSSID: ssid, wifiBSSID: bssid))
        }
    }

    private func buildFieldMap(wifiSSID: String? = nil, wifiBSSID: String? = nil) -> [String: Any] {
        let nullToken = RupeeDeviceConstants.nullToken
        let uuid = RupeeDeviceIdentityProbe.stableUUID()
        let idfv = RupeeDeviceIdentityProbe.idfv()
        let idfa = RupeeDeviceIdentityProbe.idfaOrNull()
        let screen = RupeeDeviceHardwareProbe.screenMetrics()
        let cached = RupeeDeviceNetworkProbe.currentWiFiInfo()
        let ssid = wifiSSID ?? cached.ssid
        let bssidRaw = wifiBSSID ?? cached.bssid
        let telephony = RupeeDeviceNetworkProbe.telephonyOperators()
        let networkType = RupeeDeviceNetworkProbe.networkCategory()
        let batteryLevel = RupeeDevicePowerProbe.batteryLevelPercent()
        let version = RupeeDeviceHardwareProbe.appVersionShortString()

        // LoanEase: wifiName treats empty/"0" as null; wifiSsid keeps raw SSID.
        let wifiName = RupeeDeviceNetworkProbe.wifiName(from: ssid)
        let wifiSsid = RupeeDeviceNetworkProbe.wifiSsidValue(from: ssid)
        let bssid = (bssidRaw?.isEmpty == false) ? bssidRaw! : nullToken

        let fields: [String: Any] = [
            "androidId": nullToken,
            "gaid": nullToken,
            "uuid": uuid,
            "idfa": idfa,
            "idfv": idfv,
            "phoneBoard": nullToken,
            "phoneBrand": "Apple",
            "phoneMark": UIDevice.current.name,
            "phoneType": RupeeDeviceHardwareProbe.deviceModelName(),
            "systemVersions": osStamp,
            "versionCode": version,
            "versionName": version,
            "sdkVersion": nullToken,
            "productionDate": nullToken,
            "serial": nullToken,
            "screenResolution": String(format: "%.0f-%.0f", screen.pixelWidth, screen.pixelHeight),
            "screenWidth": "\(Int(screen.pointWidth))",
            "screenHeight": "\(Int(screen.pointHeight))",
            "cpuNum": "\(ProcessInfo.processInfo.processorCount)",
            "ramCanUse": RupeeDeviceStorageProbe.ramCanUseGBString(),
            "ramTotal": RupeeDeviceStorageProbe.ramTotalGBString(),
            "cashCanUse": RupeeDeviceStorageProbe.diskFreeGBString(),
            "cashTotal": RupeeDeviceStorageProbe.diskTotalGBString(),
            "batteryLevel": batteryLevel,
            "batteryMax": "100",
            "totalBootTime": "\(RupeeDeviceHardwareProbe.elapsedSinceBootMs())",
            "totalBootTimeWake": "\(RupeeDeviceHardwareProbe.bootTimeMs())",
            "defaultLanguage": RupeeDeviceLocaleProbe.defaultLanguage(),
            "defaultTimeZone": RupeeDeviceLocaleProbe.defaultTimeZone(),
            "telephony": telephony.primary,
            "network": networkType,
            "mac": bssid,
            "wifiName": wifiName,
            "phoneNum": nullToken,
            "phoneNum2": nullToken,
            "rooted": RupeeDeviceHardwareProbe.hasSystemModificationIndicators() ? "true" : "false",
            "debugged": RupeeDeviceHardwareProbe.isBeingDebugged() ? "true" : "false",
            "simulated": RupeeDeviceHardwareProbe.isSimulator ? "true" : "false",
            "proxied": RupeeDeviceNetworkProbe.isSystemProxyEnabled() ? "true" : "false",
            "charged": RupeeDevicePowerProbe.isCharging() ? "true" : "false",
            "deviceType": "3",
            "operatingSystem": "2",
            "lastBootTime": "\(RupeeDeviceHardwareProbe.lastBootTimeMs())",
            "screenBrightness": "\(screen.brightnessPercent)",
            "slotCount": telephony.slotCount,
            "simCount": telephony.simCount,
            "telephony2": telephony.secondary,
            "wifiBssid": bssid,
            "wifiSsid": wifiSsid,
            "isvpn": RupeeDeviceNetworkProbe.isVPNOn() ? "true" : "false",
            "videoInternal": "-99",
            "imageInternal": "-99",
            "albumFile": "-99"
        ]
        return fields.mapValues { value in
            if let text = value as? String, text.isEmpty { return nullToken }
            return value
        }
    }
}
