import Foundation

public protocol TimedIdleAssertion: AnyObject {
    var held: Bool { get }
    func renew() throws
    func release() throws
}

public struct OpenLidError: LocalizedError {
    public let errorDescription: String?
    public init(_ message: String) { errorDescription = message }
}

public enum DisplayAwakeDuration: Int, CaseIterable {
    case halfHour = 30
    case oneHour = 60
    case continuous = 0

    public var seconds: TimeInterval? { self == .continuous ? nil : TimeInterval(rawValue * 60) }
}

/// Open-lid idle protection is independent of the one-shot closed-lid session.
/// Both the public system assertion and this controller have bounded renewal.
public final class OpenLidSession {
    public static let leaseSeconds: TimeInterval = 30
    public static let renewalSeconds: TimeInterval = 5
    public private(set) var requested = false
    public private(set) var deadline: TimeInterval?
    public var active: Bool { assertion.held }
    private let assertion: TimedIdleAssertion
    private var displayDuration: DisplayAwakeDuration?
    private var lastRenewal: TimeInterval?

    public init(assertion: TimedIdleAssertion) { self.assertion = assertion }
    public func setEnabled(_ enabled: Bool, now: TimeInterval, lidClosed: Bool?, systemSleeping: Bool = false,
                           displayDuration: DisplayAwakeDuration? = nil) throws {
        requested = enabled
        self.displayDuration = enabled ? displayDuration : nil
        deadline = self.displayDuration.flatMap(\.seconds).map { now + $0 }
        try tick(now: now, lidClosed: lidClosed, systemSleeping: systemSleeping)
    }
    public func disable() throws {
        requested = false
        displayDuration = nil
        deadline = nil
        lastRenewal = nil
        try assertion.release()
    }
    public func tick(now: TimeInterval, lidClosed: Bool?, systemSleeping: Bool = false) throws {
        guard requested else { try disable(); return }
        guard now.isFinite, let closed = lidClosed else {
            try disable()
            throw OpenLidError("无法读取合盖状态，开盖不休眠已关闭")
        }
        // All display sessions finish when the lid closes or the system sleeps.
        if displayDuration != nil, closed || systemSleeping || deadline.map({ now >= $0 }) == true {
            try disable(); return
        }
        if closed || systemSleeping {
            lastRenewal = nil
            try assertion.release()
            return
        }
        if let renewed = lastRenewal, now < renewed || now - renewed >= Self.leaseSeconds {
            try disable()
            throw OpenLidError("开盖不休眠连接超时，请重新开启")
        }
        if !assertion.held || lastRenewal == nil || now - lastRenewal! >= Self.renewalSeconds {
            do {
                try assertion.renew()
                lastRenewal = now
            } catch {
                try? disable()
                throw error
            }
        }
    }
}
