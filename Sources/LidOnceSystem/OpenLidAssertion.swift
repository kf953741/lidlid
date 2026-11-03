import Foundation
import IOKit.pwr_mgt
import LidOnceCore

/// Public idle-sleep API only. It does not hold the display awake, change
/// SleepDisabled, veto manual sleep, or suppress normal clamshell sleep.
/// powerd releases it after 30 seconds even if this worker freezes.
public final class OpenLidAssertion: TimedIdleAssertion {
    private var id: IOPMAssertionID?
    public var held: Bool { id != nil }
    public init() {}
    deinit { try? release() }

    public func renew() throws {
        let result: IOReturn
        if let id {
            result = IOPMAssertionSetProperty(id, kIOPMAssertionTimeoutKey as CFString,
                                             NSNumber(value: OpenLidSession.leaseSeconds))
        } else {
            let properties: [String: Any] = [
                kIOPMAssertionTypeKey: kIOPMAssertionTypePreventUserIdleSystemSleep,
                kIOPMAssertionNameKey: "LidLid · Open-lid keep awake",
                kIOPMAssertionLevelKey: kIOPMAssertionLevelOn,
                kIOPMAssertionTimeoutKey as String: OpenLidSession.leaseSeconds,
                kIOPMAssertionTimeoutActionKey as String: kIOPMAssertionTimeoutActionRelease
            ]
            var created: IOPMAssertionID = 0
            result = IOPMAssertionCreateWithProperties(properties as CFDictionary, &created)
            if result == kIOReturnSuccess { id = created }
        }
        guard result == kIOReturnSuccess else {
            throw PowerError(text: "开盖防休眠请求失败：\(PowerDriver.hex(result))")
        }
    }
    public func release() throws {
        guard let current = id else { return }
        let result = IOPMAssertionRelease(current)
        // TimeoutActionRelease may already have removed this ID. An absent
        // property record confirms there is no remaining assertion to release.
        let remaining = result == kIOReturnSuccess ? nil : IOPMAssertionCopyProperties(current)?.takeRetainedValue()
        if remaining != nil {
            throw PowerError(text: "开盖防休眠恢复失败：\(PowerDriver.hex(result))")
        }
        id = nil
    }
}
