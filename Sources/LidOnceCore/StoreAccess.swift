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

    public func permitsKeepAwake(at now: Date) -> Bool {
        switch self {
        case .lifetime: return true
        case .trial(let deadline): return now < deadline
        default: return false
        }
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
/// across relaunches. This is an offline safeguard, not a server clock.
public struct StoreAccessClock {
    private var anchorDate: Date
    private var anchorUptime: TimeInterval
    public init(wallTime: Date, lastObserved: Date?, uptime: TimeInterval) {
        anchorDate = max(wallTime, lastObserved ?? wallTime)
        anchorUptime = uptime
    }
    public mutating func now(wallTime: Date, uptime: TimeInterval) -> Date {
        anchorDate = max(wallTime, anchorDate.addingTimeInterval(max(0, uptime - anchorUptime)))
        anchorUptime = uptime
        return anchorDate
    }
}
