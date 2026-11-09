import Foundation
import Darwin

enum RupeeDeviceStorageProbe {
    static func ramTotalGBString() -> String {
        // Reference protocol rounds RAM to the nearest 256 MiB before converting to GiB.
        let mib = Int(ProcessInfo.processInfo.physicalMemory / 1_048_576)
        let rounded = ((mib + 128) / 256) * 256
        return String(format: "%.6f", Double(rounded) / 1024)
    }

    /// Available RAM = physical RAM minus active, inactive and wired pages.
    static func ramCanUseGBString() -> String {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return "-1.000000" }
        let usedPages = UInt64(stats.active_count) + UInt64(stats.inactive_count) + UInt64(stats.wire_count)
        let usedBytes = usedPages * UInt64(pageSize)
        let available = Double(ProcessInfo.processInfo.physicalMemory) - Double(usedBytes)
        return String(format: "%.6f", available / 1_073_741_824)
    }

    static func diskTotalGBString() -> String {
        diskUsageGB(isTotal: true)
    }

    static func diskFreeGBString() -> String {
        diskUsageGB(isTotal: false)
    }

    private static func diskUsageGB(isTotal: Bool) -> String {
        let key: URLResourceKey = isTotal ? .volumeTotalCapacityKey : .volumeAvailableCapacityKey
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [key]),
              let capacity = isTotal ? values.volumeTotalCapacity : values.volumeAvailableCapacity
        else {
            return "0.000000"
        }
        return gigabytes(bytes: UInt64(max(capacity, 0)))
    }

    private static func gigabytes(bytes: UInt64) -> String {
        String(format: "%.6f", Double(bytes) / 1_073_741_824.0)
    }
}
