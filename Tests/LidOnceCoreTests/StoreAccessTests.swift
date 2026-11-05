import XCTest
@testable import LidOnceCore

final class StoreAccessTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func testRequiresPurchaseAndRejectsUnrelatedProduct() {
        XCTAssertEqual(StoreAccess.evaluate([], now: start), .locked)
        XCTAssertEqual(StoreAccess.evaluate([.init(productID: "unrelated", originalPurchaseDate: start)], now: start), .locked)
        XCTAssertFalse(StoreAccess.loading.permitsKeepAwake(at: start))
    }
    func testTrialEndsAtExactlySevenDays() {
        let purchases = [StorePurchase(productID: StoreProducts.trial, originalPurchaseDate: start)]
        let end = start.addingTimeInterval(7 * 86400)
        XCTAssertEqual(StoreAccess.evaluate(purchases, now: end.addingTimeInterval(-1)), .trial(until: end))
        XCTAssertEqual(StoreAccess.evaluate(purchases, now: end), .expired)
        XCTAssertFalse(StoreAccess.trial(until: end).permitsKeepAwake(at: end))
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
}
