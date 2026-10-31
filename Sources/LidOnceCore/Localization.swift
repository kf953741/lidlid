import Foundation

public enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .simplifiedChinese : .english
    }

    public var locale: Locale {
        Locale(identifier: resolved() == .simplifiedChinese ? "zh_CN" : "en_US")
    }
}

/// The source copy is also the Chinese fallback. Agent messages stay stable on
/// the wire and are translated when displayed, so switching languages works
/// immediately for a running session, its last result, and recovery notices.
public struct AppText {
    public let language: AppLanguage
    public init(language: AppLanguage) { self.language = language }

    public func callAsFunction(_ source: String) -> String {
        guard language.resolved() == .english else { return source }
        if let value = Self.english[source] { return value }
        for (prefix, translation) in Self.englishPrefixes where source.hasPrefix(prefix) {
            return translation + source.dropFirst(prefix.count)
        }
        return source
    }

    public func duration(_ minutes: Int) -> String {
        if minutes == 0 { return self("直到开盖") }
        if language.resolved() == .simplifiedChinese {
            return minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时"
        }
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    private static let englishPrefixes = [
        "无法启动合盖进程：": "Couldn't start the session process: ",
        "无法打开合盖接口：": "Couldn't open the lid-control interface: ",
        "系统拒绝合盖设置：": "macOS rejected the lid setting: ",
        "防睡眠请求失败：": "Keep-awake request failed: "
    ]

    private static let english = [
        "盖盖": "LidLid",
        "选项": "Options",
        "返回": "Back",
        "本次合盖不休眠": "Keep awake for this lid close",
        "已关闭": "Off",
        "已开启": "On",
        "正在开启…": "Turning on…",
        "正在关闭…": "Turning off…",
        "开盖自动关闭，下次恢复正常睡眠。": "Turns off when you reopen the lid. Normal sleep returns.",
        "最长保持": "Time limit",
        "直到开盖": "Until reopened",
        "最晚结束": "Ends by",
        "电量降至 10% 或过热时自动结束": "Ends at 10% battery or if your Mac gets too hot",
        "登录时启动": "Launch at login",
        "语言": "Language",
        "跟随系统": "System default",
        "低电量保护": "Low battery cutoff",
        "高温保护": "Thermal protection",
        "自动": "Automatic",
        "当前电量": "Battery level",
        "读取中": "Reading…",
        "保持通风，放入包内前先结束本次。": "Keep your Mac ventilated. Turn off before putting it in a bag.",
        "退出盖盖": "Quit LidLid",
        "Clamshell 正在运行": "Clamshell is running",
        "需要处理": "Needs attention",
        "退出后即可开启本次合盖不休眠。": "Quit Clamshell to enable this session.",
        "退出 Clamshell": "Quit Clamshell",
        "请在系统设置 → 登录项中允许盖盖": "Allow LidLid in System Settings → Login Items.",
        "盖盖：已关闭": "LidLid: Off",
        "盖盖：已开启，仅本次合盖不休眠": "LidLid: On, keep awake for this lid close",
        "点一次，下次合盖继续运行": "One click to keep working through the next lid close",
        "合盖进程意外结束，正在恢复睡眠…": "The session process quit unexpectedly. Restoring sleep…",
        "合盖进程已结束，请重新打开盖盖": "The session process has ended. Reopen LidLid.",
        "无法确认恢复，请保持开盖并重启 Mac": "Couldn't confirm recovery. Keep the lid open and restart your Mac.",
        "意外退出后已恢复睡眠，请重新打开盖盖": "Sleep settings restored after an unexpected exit. Reopen LidLid.",
        "恢复尚未确认，正在重试；请保持开盖": "Recovery isn't confirmed. Retrying; keep the lid open.",
        "另一个盖盖会话正在运行": "Another LidLid session is already running",
        "这台 Mac 没有可读取的合盖传感器": "This Mac has no readable lid sensor",
        "无法监听合盖事件": "Couldn't monitor lid events",
        "合盖事件监听失败": "Lid event monitoring failed",
        "系统正在睡眠，本次已结束": "macOS is going to sleep. This session has ended.",
        "已取消，恢复正常合盖睡眠": "Session cancelled. Normal lid sleep restored.",
        "此版本仅支持 Apple Silicon MacBook": "This version supports Apple Silicon MacBooks only",
        "无效的时长设置": "Invalid time limit",
        "请先退出 Clamshell，避免两个软件同时控制合盖": "Quit Clamshell before enabling LidLid",
        "请先打开电脑盖子": "Open the lid before enabling LidLid",
        "请断开外接显示器后再启用": "Disconnect external displays before enabling LidLid",
        "其他程序正在接管睡眠，请先关闭它的防睡眠功能": "Another app controls sleep. Turn off its keep-awake feature first.",
        "温度过高，冷却后再启用": "Your Mac is too hot. Let it cool before trying again.",
        "无法读取电量，请稍后再试": "Couldn't read the battery level. Try again later.",
        "电量不高于 10%，请接通电源": "Battery is at or below 10%. Connect power first.",
        "正在确认合盖控制…": "Checking lid control…",
        "会话状态异常": "Unexpected session state",
        "现在可以合盖，开盖后自动结束": "Ready to close the lid. Reopening ends this session.",
        "本次已完成，下次合盖将正常睡眠": "Session complete. The next lid close will sleep normally.",
        "合盖运行中 · 开盖即结束": "Working with the lid closed. Reopening ends this session.",
        "温度过高，已恢复正常睡眠": "Your Mac is too hot. Normal sleep restored.",
        "电量读取中断，已恢复正常睡眠": "Battery readings stopped. Normal sleep restored.",
        "电量已降至 10%，已恢复正常睡眠": "Battery reached 10%. Normal sleep restored.",
        "达到设定时长，本次已结束": "Time limit reached. This session has ended.",
        "已连接外接屏，本次结束，由 macOS 管理睡眠": "External display connected. Session ended; macOS controls sleep.",
        "合盖传感器读取中断，已恢复正常睡眠": "Lid sensor readings stopped. Normal sleep restored.",
        "等待防睡眠请求释放": "Waiting for keep-awake requests to release",
        "恢复尚未确认，正在重试。请保持开盖；必要时重启 Mac。": "Recovery isn't confirmed. Retrying. Keep the lid open; restart your Mac if needed.",
        "会话已结束，恢复正常睡眠": "Session ended. Normal sleep restored.",
        "找不到合盖控制接口": "Lid-control interface not found",
        "无法确认显示器状态": "Couldn't confirm display status",
        "读取显示器失败": "Couldn't read display status"
    ]
}
