import AppKit
import IOKit
import IOKit.ps
import LidOnceCore

public struct PowerError: LocalizedError {
    public let text: String
    public init(text: String) { self.text = text }
    public var errorDescription: String? { text }
}

/// Read-only lid/power access. All keep-awake ownership belongs to the leased
/// service, so a frozen worker cannot leave an unbounded idle assertion behind.
public final class PowerDriver {
    public let root: io_service_t
    private var connection: io_connect_t = 0
    public init() throws {
        root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { throw PowerError(text: "找不到合盖控制接口") }
        let result = IOServiceOpen(root, mach_task_self_, 0, &connection)
        guard result == KERN_SUCCESS else {
            IOObjectRelease(root)
            throw PowerError(text: "无法打开合盖接口：\(Self.hex(result))")
        }
    }
    deinit {
        IOServiceClose(connection)
        IOObjectRelease(root)
    }
    public static func hex(_ result: IOReturn) -> String {
        String(format: "0x%08x", UInt32(bitPattern: result))
    }
    public func bool(_ key: String) -> Bool? {
        guard let value = IORegistryEntryCreateCFProperty(root, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return (value as! NSNumber).boolValue
    }

}

public struct BatteryReading {
    public var percent: Int?
    public var onBattery: Bool
}

public func batteryReading() -> BatteryReading {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return BatteryReading(percent: nil, onBattery: true)
    }
    let onBattery = (IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPSBatteryPowerValue
    let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
    for source in sources {
        guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
        return BatteryReading(percent: Int(Double(current) / Double(maximum) * 100), onBattery: onBattery)
    }
    return BatteryReading(percent: nil, onBattery: onBattery)
}

public func externalDisplayCount() throws -> Int {
    let maxDisplays: UInt32 = 64
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(maxDisplays, &displays, &count) == .success, count > 0 else {
        throw PowerError(text: "无法确认显示器状态")
    }
    // Ignore built-in panels and headless/virtual entries with no associated monitor
    // (Apple documents UInt32.max as the sentinel when no monitor is associated;
    // kDisplayVendorIDUnknown still represents a real unidentifiable external display).
    return displays.prefix(Int(count)).filter { id in
        guard CGDisplayIsBuiltin(id) == 0 else { return false }
        let vendor = CGDisplayVendorNumber(id)
        return vendor != UInt32.max
    }.count
}

public func conflictingApp() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: "com.rathonyi.clamshell").isEmpty
}

public func thermalLabel() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return "正常"
    case .fair: return "温热"
    case .serious: return "高温"
    case .critical: return "过热"
    @unknown default: return "未知"
    }
}
