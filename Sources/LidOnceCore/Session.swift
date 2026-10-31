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

public struct Snapshot: Codable {
    public var phase: Phase = .off
    public var message = "点一次，下次合盖继续运行"
    public var lidClosed: Bool? = nil
    public var causesSleep: Bool? = nil
    public var battery: Int? = nil
    public var onBattery = false
    public var thermal = "正常"
    public var deadline: TimeInterval? = nil
    public var error = false
    public init() {}
}
