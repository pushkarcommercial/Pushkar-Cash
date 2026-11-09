import UIKit
import Darwin

enum RupeeDeviceHardwareProbe {
    struct ScreenMetrics {
        let pointWidth: CGFloat
        let pointHeight: CGFloat
        let pixelWidth: CGFloat
        let pixelHeight: CGFloat
        let brightnessPercent: Int
    }

    static func screenMetrics() -> ScreenMetrics {
        let screen = UIScreen.main
        let scale = screen.scale
        let pointWidth = screen.bounds.size.width
        let pointHeight = screen.bounds.size.height
        return ScreenMetrics(
            pointWidth: pointWidth,
            pointHeight: pointHeight,
            pixelWidth: pointWidth * scale,
            pixelHeight: pointHeight * scale,
            brightnessPercent: Int(screen.brightness * 100)
        )
    }

    static func hardwareModelIdentifier() -> String {
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    static func deviceModelName() -> String {
        let machine = hardwareModelIdentifier()
        return modelMap[machine] ?? machine
    }

    static func appVersionShortString() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Wall-clock elapsed time includes sleep; systemUptime is reported separately.
    static func elapsedSinceBootMs() -> Int64 {
        guard let boot = kernelBootTime() else { return -1 }
        return Int64(Date().timeIntervalSince1970 * 1000) - boot
    }

    static func lastBootTimeMs() -> Int64 {
        guard let boot = kernelBootTime() else { return -1 }
        return (boot / 1000) * 1000
    }

    static func bootTimeMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    private static func kernelBootTime() -> Int64? {
        var time = timeval()
        var count = MemoryLayout<timeval>.size
        var query: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        let status = query.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, UInt32($0.count), &time, &count, nil, 0)
        }
        guard status == 0, time.tv_sec > 0 else { return nil }
        return Int64(time.tv_sec) * 1000 + Int64(time.tv_usec) / 1000
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func isBeingDebugged() -> Bool {
        var process = kinfo_proc()
        var count = MemoryLayout<kinfo_proc>.size
        var query: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let status = query.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, UInt32($0.count), &process, &count, nil, 0)
        }
        return status == 0 && (process.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Independent, read-only indicators; not a copy of SystemServices' legacy scoring.
    static func hasSystemModificationIndicators() -> Bool {
        guard !isSimulator else { return false }
        return ["/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib",
                "/var/jb", "/usr/sbin/sshd"].contains {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    // Wire display values are protocol data; collection remains independently implemented.
    private static let modelMap: [String: String] = [
        "arm64": "iPhone Simulator",
        "i386": "iPhone Simulator",
        "iPhone1,1": "iPhone",
        "iPhone1,2": "iPhone 3G",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,4": "iPhone 8",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        "iPhone18,5": "iPhone 17e",
        "iPhone19,2": "iPhone 18 Pro",
        "iPhone19,3": "iPhone 18 Pro Max",
        "iPhone19,4": "iPhone Duo",
        "iPhone19,7": "iPhone 18 Pro Max",
        "iPhone2,1": "iPhone 3GS",
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4",
        "iPhone4,1": "iPhone 4s",
        "iPhone5,1": "iPhone 5",
        "iPhone5,2": "iPhone 5",
        "iPhone5,3": "iPhone 5c",
        "iPhone5,4": "iPhone 5c",
        "iPhone6,1": "iPhone 5s",
        "iPhone6,2": "iPhone 5s",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone7,2": "iPhone 6",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,3": "iPhone 7",
        "iPhone9,4": "iPhone 7 Plus",
        "x86_64": "iPhone Simulator"
    ]
}
