import XCTest
@testable import LidOnceCore

private final class Assertion: TimedIdleAssertion {
    var held = false
    var renewals = 0
    var rejectRenewal = false
    var rejectRelease = false
    func renew() throws {
        if rejectRenewal { throw OpenLidError("renew rejected") }
        held = true; renewals += 1
    }
    func release() throws {
        if rejectRelease { throw OpenLidError("release rejected") }
        held = false
    }
}
final class OpenLidSessionTests: XCTestCase {
    func testTimedDisplaySessionReleasesAtItsDeadline() throws {
        for duration in [DisplayAwakeDuration.halfHour, .oneHour] {
            let driver = Assertion()
            let session = OpenLidSession(assertion: driver)
            try session.setEnabled(true, now: 10, lidClosed: false, displayDuration: duration)
            let deadline = 10 + Double(duration.rawValue * 60)
            XCTAssertEqual(session.deadline, deadline)
            for time in stride(from: 15, to: deadline, by: 5) {
                try session.tick(now: time, lidClosed: false)
            }
            XCTAssertTrue(session.active)
            try session.tick(now: deadline, lidClosed: false)
            XCTAssertFalse(session.active)
            XCTAssertFalse(session.requested)
            XCTAssertNil(session.deadline)
        }
    }

    func testDisplaySessionEndsOnLidCloseOrSleepWithoutResuming() throws {
        for duration in DisplayAwakeDuration.allCases {
            for lidClosed in [true, false] {
                let driver = Assertion()
                let session = OpenLidSession(assertion: driver)
                try session.setEnabled(true, now: 0, lidClosed: false, displayDuration: duration)
                try session.tick(now: 1, lidClosed: lidClosed, systemSleeping: !lidClosed)
                XCTAssertFalse(driver.held)
                XCTAssertNil(session.deadline)
                try session.tick(now: 2, lidClosed: false)
                XCTAssertFalse(session.active)
                XCTAssertFalse(session.requested)
                XCTAssertEqual(driver.renewals, 1)
            }
        }
    }

    func testContinuousDisplaySessionHasNoDeadlineAndCanBeTurnedOff() throws {
        let driver = Assertion()
        let session = OpenLidSession(assertion: driver)
        try session.setEnabled(true, now: 0, lidClosed: false, displayDuration: .continuous)
        for time in stride(from: 5.0, through: 7200.0, by: 5) {
            try session.tick(now: time, lidClosed: false)
        }
        XCTAssertNil(session.deadline)
        XCTAssertTrue(session.requested)
        XCTAssertTrue(driver.held)
        try session.setEnabled(false, now: 7201, lidClosed: false)
        XCTAssertFalse(session.requested)
        XCTAssertFalse(driver.held)
    }

    func testRenewalIsBoundedAndTurningOffReleases() throws {
        let driver = Assertion()
        let active = OpenLidSession(assertion: driver)
        XCTAssertFalse(active.requested)
        try active.setEnabled(true, now: 0, lidClosed: false)
        XCTAssertTrue(active.active)
        for time in stride(from: 0.25, to: 5.0, by: 0.25) { try active.tick(now: time, lidClosed: false) }
        XCTAssertEqual(driver.renewals, 1)
        try active.tick(now: 5, lidClosed: false)
        XCTAssertEqual(driver.renewals, 2)
        try active.setEnabled(false, now: 6, lidClosed: false)
        XCTAssertFalse(active.requested); XCTAssertFalse(driver.held)
    }
    func testClosesPauseAndReopeningResumesWithoutChangingOneShot() throws {
        let driver = Assertion()
        let active = OpenLidSession(assertion: driver)
        var oneShot = OneShot()
        XCTAssertTrue(oneShot.arm(now: 0, minutes: 0, lidClosed: false))
        try active.setEnabled(true, now: 0, lidClosed: false)
        XCTAssertFalse(oneShot.observe(closed: true))
        try active.tick(now: 1, lidClosed: true)
        XCTAssertFalse(active.active); XCTAssertTrue(active.requested)
        // A long physical sleep must not look like a stale live assertion:
        // there is no assertion while paused, and reopening starts a new lease.
        XCTAssertTrue(oneShot.observe(closed: false))
        try active.tick(now: 3600, lidClosed: false)
        XCTAssertTrue(active.active); XCTAssertEqual(driver.renewals, 2)
        XCTAssertEqual(oneShot.phase, .restoring)
    }
    func testManualSleepSuspendsUntilWake() throws {
        let driver = Assertion()
        let active = OpenLidSession(assertion: driver)
        try active.setEnabled(true, now: 0, lidClosed: false)
        try active.tick(now: 1, lidClosed: false, systemSleeping: true)
        try active.tick(now: 120, lidClosed: false, systemSleeping: true)
        XCTAssertTrue(active.requested); XCTAssertFalse(driver.held)
        try active.tick(now: 121, lidClosed: false)
        XCTAssertTrue(driver.held)
    }
    func testUnknownSensorAndFrozenRenewalEndRequest() throws {
        for brokenSensor in [true, false] {
            let driver = Assertion()
            let session = OpenLidSession(assertion: driver)
            try session.setEnabled(true, now: 0, lidClosed: false)
            XCTAssertThrowsError(try session.tick(now: brokenSensor ? 1 : 30, lidClosed: brokenSensor ? nil : false))
            XCTAssertFalse(driver.held)
        }
    }
    func testRenewalFailureDoesNotSilentlyRearm() throws {
        let driver = Assertion(); let session = OpenLidSession(assertion: driver)
        try session.setEnabled(true, now: 0, lidClosed: false)
        driver.rejectRenewal = true
        XCTAssertThrowsError(try session.tick(now: 5, lidClosed: false))
        XCTAssertFalse(session.requested); XCTAssertFalse(driver.held)
        driver.rejectRenewal = false
        try session.tick(now: 6, lidClosed: false)
        XCTAssertFalse(driver.held)
    }
    func testReleaseFailureRemainsVisibleAndRetries() throws {
        let driver = Assertion(); let session = OpenLidSession(assertion: driver)
        try session.setEnabled(true, now: 0, lidClosed: false)
        driver.rejectRelease = true
        XCTAssertThrowsError(try session.disable())
        XCTAssertFalse(session.requested); XCTAssertTrue(session.active)
        driver.rejectRelease = false
        try session.tick(now: 1, lidClosed: false)
        XCTAssertFalse(session.active)
    }
}
