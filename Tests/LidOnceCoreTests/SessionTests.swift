import XCTest
@testable import LidOnceCore

final class SessionTests: XCTestCase {
    func testOnlyOneCloseIsConsumed() {
        var session = OneShot()
        XCTAssertTrue(session.arm(now: 0, minutes: 0, lidClosed: false))
        for _ in 0..<50 { XCTAssertFalse(session.observe(closed: false)) }
        XCTAssertEqual(session.phase, .armed)
        XCTAssertFalse(session.observe(closed: true))
        XCTAssertFalse(session.observe(closed: true))
        XCTAssertEqual(session.phase, .closed)
        XCTAssertTrue(session.observe(closed: false))
        session.reset()
        XCTAssertFalse(session.observe(closed: true))
        XCTAssertFalse(session.observe(closed: false))
        XCTAssertEqual(session.phase, .off)
    }
    func testNeverArmsWithClosedLidOrOverwritesActiveSession() {
        var session = OneShot()
        XCTAssertFalse(session.arm(now: 0, minutes: 0, lidClosed: true))
        XCTAssertTrue(session.arm(now: 20, minutes: 60, lidClosed: false))
        XCTAssertFalse(session.arm(now: 40, minutes: 0, lidClosed: false))
        XCTAssertEqual(session.deadline, 3620)
    }
    func testDeadlineAndCancelReset() {
        var session = OneShot()
        XCTAssertTrue(session.arm(now: 100, minutes: 30, lidClosed: false))
        XCTAssertFalse(session.expired(now: 1899))
        XCTAssertTrue(session.expired(now: 1900))
        session.reset()
        XCTAssertNil(session.deadline)
        XCTAssertFalse(session.expired(now: 99999))
        XCTAssertTrue(session.arm(now: 200, minutes: 0, lidClosed: false))
        XCTAssertFalse(session.expired(now: 99999))
    }
    func testManyObservedSequencesNeverConsumeBeforeClose() {
        for mask in 0..<256 {
            var session = OneShot()
            XCTAssertTrue(session.arm(now: 0, minutes: 0, lidClosed: false))
            var sawClose = false
            var stopped = false
            for bit in 0..<8 {
                let closed = (mask & (1 << bit)) != 0
                let stop = session.observe(closed: closed)
                XCTAssertEqual(stop, !stopped && sawClose && !closed)
                if stop { session.reset(); stopped = true }
                if !stopped && closed { sawClose = true }
            }
        }
    }
}
