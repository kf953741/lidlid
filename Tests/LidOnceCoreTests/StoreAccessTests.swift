import XCTest
@testable import LidOnceCore

final class StoreAccessTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func testRequiresPurchaseAndRejectsUnrelatedProduct() {
        XCTAssertEqual(StoreAccess.evaluate([], now: start), .locked)
        XCTAssertEqual(StoreAccess.evaluate([.init(productID: "unrelated", originalPurchaseDate: start)], now: start), .locked)
        XCTAssertFalse(StoreAccess.loading.permitsStartingClosedLidSession(at: start))
    }
    func testTrialEndsAtExactlySevenDays() {
        let purchases = [StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start)]
        let end = start.addingTimeInterval(7 * 86400)
        XCTAssertEqual(StoreAccess.evaluate(purchases, now: end.addingTimeInterval(-1)), .trial(until: end))
        XCTAssertEqual(StoreAccess.evaluate(purchases, now: end), .expired)
        XCTAssertFalse(StoreAccess.trial(until: end).permitsStartingClosedLidSession(at: end))
    }
    func testRestoreDoesNotRestartTrial() {
        let old = StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start)
        let today = start.addingTimeInterval(10 * 86400)
        XCTAssertEqual(StoreAccess.evaluate([old], now: today), .expired)
        let duplicate = StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: today)
        XCTAssertEqual(StoreAccess.evaluate([old, duplicate], now: today), .expired)
    }
    func testLifetimeWinsOverExpiredTrialAndHasNoExpiry() {
        let p = [StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start),
                 StorePurchase(productID: StoreProducts.lifetime, originalPurchaseDate: start)]
        XCTAssertEqual(StoreAccess.evaluate(p, now: start.addingTimeInterval(1000 * 86400)), .lifetime)
        XCTAssertEqual(StoreAccess.evaluate(p, now: start.addingTimeInterval(-1000)), .lifetime)
    }
    func testRevokedPurchasesAndFuturePurchasesDoNotGrantAccess() {
        let refunded = StorePurchase(productID: StoreProducts.lifetime, originalPurchaseDate: start, revoked: true)
        XCTAssertEqual(StoreAccess.evaluate([refunded], now: start), .locked)
        let future = StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start.addingTimeInterval(1))
        XCTAssertEqual(StoreAccess.evaluate([future], now: start), .locked)
    }
    func testRefundFallsBackToRemainingTrial() {
        let p = [StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start),
                 StorePurchase(productID: StoreProducts.lifetime, originalPurchaseDate: start, revoked: true)]
        XCTAssertEqual(StoreAccess.evaluate(p, now: start), .trial(until: start.addingTimeInterval(7 * 86400)))
    }
    func testClockRejectsWallClockRollbackWithinSessionAndAcrossLaunches() {
        var clock = StoreAccessClock(wallTime: start, lastObserved: nil, uptime: 100)
        XCTAssertEqual(clock.now(wallTime: start.addingTimeInterval(-500), uptime: 200), start.addingTimeInterval(100))
        XCTAssertEqual(clock.now(wallTime: start.addingTimeInterval(1000), uptime: 201), start.addingTimeInterval(1000))
        XCTAssertEqual(clock.now(wallTime: start, uptime: 211), start.addingTimeInterval(1010))
        var relaunched = StoreAccessClock(wallTime: start.addingTimeInterval(-500), lastObserved: start, uptime: 10)
        XCTAssertEqual(relaunched.now(wallTime: start.addingTimeInterval(-500), uptime: 30), start.addingTimeInterval(20))
    }
    func testOpenLidModeAndCleanupAreFreeInEveryStoreState() {
        let states: [StoreAccess] = [.loading, .locked, .expired, .lifetime,
                                    .trial(until: start.addingTimeInterval(-1))]
        for state in states {
            for action in ["open-awake-on", "open-awake-off", "ping", "stop", "quit"] {
                XCTAssertTrue(state.permits(Command(action), inStoreEdition: true, at: start), "\(state) \(action)")
            }
        }
    }
    func testOnlyNewClosedLidStartsRequireAnActiveStoreEntitlement() {
        for state in [StoreAccess.loading, .locked, .expired, .trial(until: start)] {
            XCTAssertFalse(state.permits(Command("arm"), inStoreEdition: true, at: start))
            XCTAssertTrue(state.permits(Command("arm"), inStoreEdition: false, at: start))
        }
        XCTAssertTrue(StoreAccess.lifetime.permits(Command("arm"), inStoreEdition: true, at: start))
        XCTAssertTrue(StoreAccess.trial(until: start.addingTimeInterval(1))
            .permits(Command("arm"), inStoreEdition: true, at: start))
    }
    func testTrialStartsOnlyOnceAfterCompatibilitySetup() {
        XCTAssertFalse(StoreAccess.locked.permitsStartingTrial(compatibilityReady: false))
        XCTAssertTrue(StoreAccess.locked.permitsStartingTrial(compatibilityReady: true))
        for state in [StoreAccess.loading, .expired, .lifetime, .trial(until: start)] {
            XCTAssertFalse(state.permitsStartingTrial(compatibilityReady: true))
        }
    }

    func testForwardClockJumpThenCorrectionDoesNotExpireTrial() {
        var clock = StoreAccessClock(wallTime: start, lastObserved: nil, uptime: 100)
        // Simulate a bogus +30 day system clock jump while awake, then immediate correction.
        let jumped = clock.now(wallTime: start.addingTimeInterval(30 * 86400), uptime: 105)
        XCTAssertEqual(jumped, start.addingTimeInterval(5))
        XCTAssertEqual(clock.persistableDate, start)
        let corrected = clock.now(wallTime: start.addingTimeInterval(10), uptime: 110)
        XCTAssertEqual(corrected, start.addingTimeInterval(10))
        let trial = [StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start)]
        XCTAssertEqual(StoreAccess.evaluate(trial, now: corrected), .trial(until: start.addingTimeInterval(7 * 86400)))
    }

    func testSnapshotBackwardCompatibleDecoding() throws {
        let minimal = #"{"phase":"off","message":"ok"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Snapshot.self, from: minimal)
        XCTAssertEqual(decoded.phase, .off)
        XCTAssertTrue(decoded.hasLidSensor)
        XCTAssertNil(decoded.sleepDisabled)
    }
}
