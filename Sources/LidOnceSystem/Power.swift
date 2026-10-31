import AppKit
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import LidOnceCore

public struct PowerError: LocalizedError {
    public let text: String
    public init(text: String) { self.text = text }
    public var errorDescription: String? { text }
}

/// Uses the clamshell selector declared by the macOS SDK in IOPMLibDefs.h.
/// SDK availability does not guarantee behavior on every model or App Review approval.
public final class PowerDriver {
    public let root: io_service_t
    private var connection: io_connect_t = 0
    private var assertions: [IOPMAssertionID] = []
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
        releaseAssertions()
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
    public func suppressLidSleep(_ suppress: Bool) throws {
        var value: UInt64 = suppress ? 1 : 0
        let result = IOConnectCallScalarMethod(connection, UInt32(kPMSetClamshellSleepState), &value, 1, nil, nil)
        guard result == kIOReturnSuccess else {
            throw PowerError(text: "系统拒绝合盖设置：\(Self.hex(result))")
        }
    }
    public func holdAssertions() throws {
        guard assertions.isEmpty else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                               IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "LidLid · 单次合盖" as CFString, &id)
        guard result == kIOReturnSuccess else {
            throw PowerError(text: "防睡眠请求失败：\(Self.hex(result))")
        }
        assertions.append(id)
    }

    public func releaseAssertions() {
        assertions = assertions.filter { IOPMAssertionRelease($0) != kIOReturnSuccess }
    }
    public var hasAssertions: Bool { !assertions.isEmpty }
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
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0, count <= 64 else {
        throw PowerError(text: "无法确认显示器状态")
    }
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
        throw PowerError(text: "读取显示器失败")
    }
    return displays.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count
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
