import XCTest
@testable import LidOnceCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageAndExplicitOverride() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-CN"]), .english)
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en"]), .simplifiedChinese)
    }

    func testExistingSessionResultChangesLanguageWithoutChangingTheMessage() {
        let message = "本次已完成，下次合盖将正常睡眠"
        XCTAssertEqual(AppText(language: .english)(message), "Session complete. The next lid close will sleep normally.")
        XCTAssertEqual(AppText(language: .simplifiedChinese)(message), message)
    }

    func testNativeDiagnosticCodesSurviveTranslation() {
        let english = AppText(language: .english)
        XCTAssertEqual(english("系统拒绝合盖设置：0xe00002c7"), "macOS rejected the lid setting: 0xe00002c7")
        XCTAssertEqual(english("Unrecognized OS diagnostic (42)"), "Unrecognized OS diagnostic (42)")
        XCTAssertEqual(english("恢复尚未确认，正在重试；请保持开盖"), "Recovery isn't confirmed. Retrying; keep the lid open.")
    }

    func testDurationPluralization() {
        let english = AppText(language: .english), chinese = AppText(language: .simplifiedChinese)
        XCTAssertEqual(english.duration(0), "Until reopened")
        XCTAssertEqual(english.duration(30), "30 minutes")
        XCTAssertEqual(english.duration(60), "1 hour")
        XCTAssertEqual(english.duration(120), "2 hours")
        XCTAssertEqual(chinese.duration(0), "直到开盖")
        XCTAssertEqual(chinese.duration(30), "30 分钟")
        XCTAssertEqual(chinese.duration(120), "2 小时")
    }
}
