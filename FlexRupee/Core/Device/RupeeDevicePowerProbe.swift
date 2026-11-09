import UIKit

enum RupeeDevicePowerProbe {
    static func isCharging() -> Bool {
        enableBatteryMonitoring()
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    static func batteryLevelPercent() -> String {
        enableBatteryMonitoring()
        let level = UIDevice.current.batteryLevel
        guard level > 0 else { return "-1" }
        return NSNumber(value: level * 100).stringValue
    }

    private static func enableBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
}
