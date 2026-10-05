import Foundation
#if canImport(Metal)
import Metal
#endif

public struct DeviceSpecs: Equatable {
    public var machineIdentifier: String
    public var totalRAMBytes: UInt64
    public var availableMemoryBytes: UInt64
    public var metalWorkingSetBytes: UInt64
    public var hasMetalDevice: Bool
    public var cpuCores: Int
    public var storageAvailableBytes: Int64

    public var totalRAMGigabytes: Double {
        Double(totalRAMBytes) / (1024 * 1024 * 1024)
    }

    public var availableMemoryGigabytes: Double {
        Double(availableMemoryBytes) / (1024 * 1024 * 1024)
    }
}

public final class DeviceProfile {
    public static let shared = DeviceProfile()

    public init() {}

    public func currentSpecs() -> DeviceSpecs {
        let machineId = getMachineIdentifier()
        let totalRAM = getTotalMemory()
        let availableMem = getAvailableMemory(totalFallback: totalRAM)
        let (hasMetal, metalBudget) = getMetalBudget(totalRAM: totalRAM)
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let storage = getAvailableStorage()

        return DeviceSpecs(
            machineIdentifier: machineId,
            totalRAMBytes: totalRAM,
            availableMemoryBytes: availableMem,
            metalWorkingSetBytes: metalBudget,
            hasMetalDevice: hasMetal,
            cpuCores: cores,
            storageAvailableBytes: storage
        )
    }

    private func getMachineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iPhone-Unknown" : identifier
    }

    private func getTotalMemory() -> UInt64 {
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memSize, &size, nil, 0) == 0 {
            return memSize
        }
        return ProcessInfo.processInfo.physicalMemory
    }

    private func getAvailableMemory(totalFallback: UInt64) -> UInt64 {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            let avail = os_proc_available_memory()
            if avail > 0 {
                return UInt64(avail)
            }
        }
        #endif
        // Fallback: estimate 65% of physical memory
        return UInt64(Double(totalFallback) * 0.65)
    }

    private func getMetalBudget(totalRAM: UInt64) -> (Bool, UInt64) {
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            let workingSet = device.recommendedMaxWorkingSetSize
            return (true, workingSet > 0 ? workingSet : UInt64(Double(totalRAM) * 0.60))
        }
        #endif
        return (false, 0)
    }

    private func getAvailableStorage() -> Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let avail = values.volumeAvailableCapacityForImportantUsage {
            return avail
        }
        return 10 * 1024 * 1024 * 1024 // 10 GB fallback
    }
}
