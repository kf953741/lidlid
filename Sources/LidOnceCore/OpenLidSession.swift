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

/// Open-lid idle protection is independent of the one-shot closed-lid session.
/// Both the public system assertion and this controller have bounded renewal.
public final class OpenLidSession {
    public static let leaseSeconds: TimeInterval = 30
    public static let renewalSeconds: TimeInterval = 5
    public private(set) var requested = false
    public var active: Bool { assertion.held }
    private let assertion: TimedIdleAssertion
    private var lastRenewal: TimeInterval?

    public init(assertion: TimedIdleAssertion) { self.assertion = assertion }
    public func setEnabled(_ enabled: Bool, now: TimeInterval, lidClosed: Bool?, systemSleeping: Bool = false) throws {
        requested = enabled
        try tick(now: now, lidClosed: lidClosed, systemSleeping: systemSleeping)
    }
    public func disable() throws {
        requested = false
        lastRenewal = nil
        try assertion.release()
    }
    public func tick(now: TimeInterval, lidClosed: Bool?, systemSleeping: Bool = false) throws {
        guard requested else { try disable(); return }
        guard now.isFinite, let closed = lidClosed else {
            try disable()
            throw OpenLidError("无法读取合盖状态，开盖不休眠已关闭")
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
                requested = false
                lastRenewal = nil
                try? assertion.release()
                throw error
            }
        }
    }
}
