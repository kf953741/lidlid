import Foundation

public enum Phase: String, Codable {
    case off, starting, armed, closed, restoring
    public var active: Bool { self == .starting || self == .armed || self == .closed }
}

/// Only the off -> armed -> closed -> off sequence is allowed to consume a close.
/// An open reading while waiting for a close must never consume the session.
public struct OneShot {
    public private(set) var phase: Phase = .off
    public private(set) var beganAt: TimeInterval?
    public private(set) var deadline: TimeInterval?
    public init() {}
    public mutating func arm(now: TimeInterval, minutes: Int, lidClosed: Bool) -> Bool {
        guard phase == .off, !lidClosed, minutes >= 0 else { return false }
        phase = .armed
        beganAt = now
        deadline = minutes > 0 ? now + Double(minutes * 60) : nil
        return true
    }
    /// Returns true only for the first real closed -> open transition of this session.
    public mutating func observe(closed: Bool) -> Bool {
        if phase == .armed && closed { phase = .closed; return false }
        if phase == .closed && !closed { phase = .restoring; return true }
        return false
    }
    public func expired(now: TimeInterval) -> Bool {
        phase.active && deadline.map { now >= $0 } == true
    }
    public mutating func reset() { self = OneShot() }
}

public struct Command: Codable {
    public var action: String
    public var minutes: Int?
    public init(_ action: String, minutes: Int? = nil) {
        self.action = action; self.minutes = minutes
    }
}

public struct DisplayAwakeStatus: Codable, Equatable {
    public var active: Bool
    public var requested: Bool
    public var deadline: TimeInterval?
    public var error: String?

    public init(active: Bool, requested: Bool, deadline: TimeInterval?, error: String?) {
        self.active = active
        self.requested = requested
        self.deadline = deadline
        self.error = error
    }
}

public struct Snapshot: Codable, Equatable {
    public var compatibilityReady = false
    public var compatibilityMessage = "请先安装并授权盖盖兼容组件"
    public var phase: Phase = .off
    public var hasLidSensor = true
    public var sleepDisabled: Bool? = nil
    public var openAwakeRequested = false
    public var openAwakeActive = false
    public var openAwakeMessage = "屏幕仍可自动熄灭，合盖时暂停"
    public var openAwakeError = false
    public var displayAwake: DisplayAwakeStatus?
    public var agentPID: Int32? = nil
    public var sandboxContainer: String? = nil
    public var message = "点一次，下次合盖继续运行"
    public var lidClosed: Bool? = nil
    public var causesSleep: Bool? = nil
    public var battery: Int? = nil
    public var onBattery = false
    public var thermal = "正常"
    public var deadline: TimeInterval? = nil
    public var error = false
    public init() {}

    public init(from decoder: Decoder) throws {
        let defaults = Snapshot()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compatibilityReady = try c.decodeIfPresent(Bool.self, forKey: .compatibilityReady) ?? defaults.compatibilityReady
        compatibilityMessage = try c.decodeIfPresent(String.self, forKey: .compatibilityMessage) ?? defaults.compatibilityMessage
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? defaults.phase
        hasLidSensor = try c.decodeIfPresent(Bool.self, forKey: .hasLidSensor) ?? defaults.hasLidSensor
        sleepDisabled = try c.decodeIfPresent(Bool.self, forKey: .sleepDisabled)
        openAwakeRequested = try c.decodeIfPresent(Bool.self, forKey: .openAwakeRequested) ?? defaults.openAwakeRequested
        openAwakeActive = try c.decodeIfPresent(Bool.self, forKey: .openAwakeActive) ?? defaults.openAwakeActive
        openAwakeMessage = try c.decodeIfPresent(String.self, forKey: .openAwakeMessage) ?? defaults.openAwakeMessage
        openAwakeError = try c.decodeIfPresent(Bool.self, forKey: .openAwakeError) ?? defaults.openAwakeError
        displayAwake = try c.decodeIfPresent(DisplayAwakeStatus.self, forKey: .displayAwake)
        agentPID = try c.decodeIfPresent(Int32.self, forKey: .agentPID)
        sandboxContainer = try c.decodeIfPresent(String.self, forKey: .sandboxContainer)
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? defaults.message
        lidClosed = try c.decodeIfPresent(Bool.self, forKey: .lidClosed)
        causesSleep = try c.decodeIfPresent(Bool.self, forKey: .causesSleep)
        battery = try c.decodeIfPresent(Int.self, forKey: .battery)
        onBattery = try c.decodeIfPresent(Bool.self, forKey: .onBattery) ?? defaults.onBattery
        thermal = try c.decodeIfPresent(String.self, forKey: .thermal) ?? defaults.thermal
        deadline = try c.decodeIfPresent(TimeInterval.self, forKey: .deadline)
        error = try c.decodeIfPresent(Bool.self, forKey: .error) ?? defaults.error
    }
}
