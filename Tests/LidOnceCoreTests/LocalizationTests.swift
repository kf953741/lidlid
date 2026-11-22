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

    func testSnapshotEquatableAndEnglishSentenceCase() {
        let a = Snapshot(), b = Snapshot()
        XCTAssertEqual(a, b)
        var c = Snapshot(); c.battery = 88
        XCTAssertNotEqual(a, c)
        let english = AppText(language: .english)
        XCTAssertEqual(english("屏幕常亮"), "Keep display awake")
        XCTAssertEqual(english("持续"), "Until off")
        XCTAssertEqual(english("系统睡眠设置响应异常"), "Unexpected sleep setting response")
        XCTAssertEqual(english("返回盖盖，永久解锁后即可开启合盖功能。"),
                       "Return to LidLid and unlock lifetime access to use closed-lid mode.")
    }

    func testAllSourceChineseStringsAreTranslated() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        let english = AppText(language: .english)
        let skippedLiterals: Set<String> = ["简体中文", "中文", "系统 / System"]
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        let stringRegex = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        let cjkRegex = try NSRegularExpression(pattern: #"[\u4e00-\u9fff]"#)
        var missing: [String] = []

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift", url.lastPathComponent != "Localization.swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = rawLine.components(separatedBy: "//").first ?? ""
                let nsLine = line as NSString
                for match in stringRegex.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let literal = nsLine.substring(with: match.range(at: 1))
                    guard cjkRegex.firstMatch(in: literal, range: NSRange(location: 0, length: (literal as NSString).length)) != nil else { continue }
                    if skippedLiterals.contains(literal) || literal.hasPrefix("只读检查；") { continue }
                    let probe = literal.replacingOccurrences(of: #"\([^)]*\)"#, with: "X", options: .regularExpression)
                    if english(probe) == probe {
                        missing.append("\(url.lastPathComponent):\(index + 1): \(literal)")
                    }
                }
            }
        }
        XCTAssertEqual(missing, [], "Untranslated Chinese strings found in Sources/: \(missing.joined(separator: ", "))")
    }
}
