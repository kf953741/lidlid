import Foundation

public enum StoreProducts {
    public static let trial = "dev.kf.lidonce.trial7days"
    public static let lifetime = "dev.kf.lidonce.lifetime"
    public static let all = [trial, lifetime]
    public static let trialDuration: TimeInterval = 7 * 24 * 60 * 60
}

/// Only the StoreKit adapter may turn a verified non-consumable transaction
/// into a record. Restoring uses the original purchase date, never today.
public struct StorePurchase: Equatable {
    public let productID: String
    public let originalPurchaseDate: Date
    public let revoked: Bool
    public init(productID: String, originalPurchaseDate: Date, revoked: Bool = false) {
        self.productID = productID
        self.originalPurchaseDate = originalPurchaseDate
        self.revoked = revoked
    }
}

public enum StoreAccess: Equatable {
    case loading, locked, expired, lifetime
    case trial(until: Date)

    public func permitsStartingClosedLidSession(at now: Date) -> Bool {
        switch self {
        case .lifetime: return true
        case .trial(let deadline): return now < deadline
        default: return false
        }
    }

    /// Licensing only guards a new closed-lid session. Heartbeats, cleanup and
    /// the permanently free open-lid mode remain available in every state.
    /// Entitlement changes never emit a stop command for an accepted session.
    public func permits(_ command: Command, inStoreEdition: Bool, at now: Date) -> Bool {
        command.action != "arm" || !inStoreEdition || permitsStartingClosedLidSession(at: now)
    }

    public func permitsStartingTrial(compatibilityReady: Bool) -> Bool {
        self == .locked && compatibilityReady
    }

    public static func evaluate(_ purchases: [StorePurchase], now: Date) -> StoreAccess {
        let valid = purchases.filter { !$0.revoked }
        if valid.contains(where: { $0.productID == StoreProducts.lifetime }) { return .lifetime }
        guard let start = valid.filter({ $0.productID == StoreProducts.trial && $0.originalPurchaseDate <= now })
            .map(\.originalPurchaseDate).min() else { return .locked }
        let deadline = start.addingTimeInterval(StoreProducts.trialDuration)
        return now < deadline ? .trial(until: deadline) : .expired
    }
}

/// Keep the trial clock moving during a running process even if wall time is
/// moved backwards. A persisted high-water date also prevents simple rollback
/// across relaunches. Guard against sudden bogus forward clock jumps within an
/// awake session so correcting a bad system date cannot prematurely expire a trial.
public struct StoreAccessClock {
    private static let maxUnverifiedForwardJump: TimeInterval = 12 * 60 * 60
    private var anchorDate: Date
    private var anchorUptime: TimeInterval
    private var persistedAnchor: Date
    public init(wallTime: Date, lastObserved: Date?, uptime: TimeInterval) {
        let initial = max(wallTime, lastObserved ?? wallTime)
        anchorDate = initial
        persistedAnchor = initial
        anchorUptime = uptime
    }
    public mutating func now(wallTime: Date, uptime: TimeInterval) -> Date {
        let deltaUptime = max(0, uptime - anchorUptime)
        let monotonic = anchorDate.addingTimeInterval(deltaUptime)
        let forwardDelta = wallTime.timeIntervalSince(monotonic)
        if forwardDelta > Self.maxUnverifiedForwardJump {
            // Sudden huge forward jump while awake: keep monotonic baseline so
            // correcting an accidental system-clock error does not burn a trial.
            anchorDate = monotonic
        } else {
            anchorDate = max(wallTime, monotonic)
            persistedAnchor = max(persistedAnchor, anchorDate)
        }
        anchorUptime = uptime
        return anchorDate
    }
    public var persistableDate: Date { persistedAnchor }
}
