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
        "开盖防休眠请求失败：": "Open-lid keep-awake request failed: ",
        "开盖防休眠恢复失败：": "Could not release open-lid keep-awake: ",
        "无法启动合盖进程：": "Couldn't start the session process: ",
        "无法打开合盖接口：": "Couldn't open the lid-control interface: ",
        "系统拒绝合盖设置：": "macOS rejected the lid setting: ",
        "防睡眠请求失败：": "Keep-awake request failed: "
    ]

    private static let english = [
        "合盖之前，准备一次": "Set up closed-lid mode once",
        "免费组件，只需安装一次。开盖功能无需安装。": "A free, one-time install. Open-lid mode works without it.",
        "下载免费组件": "Download free component",
        "点下方按钮，浏览器会直接下载官方 DMG。": "Use the button below to download the official DMG in your browser.",
        "放入应用程序": "Move to Applications",
        "打开 DMG，将 LidLid Compatibility 拖入「应用程序」。": "Open the DMG and drag LidLid Compatibility into Applications.",
        "打开组件并授权": "Open component & approve",
        "在组件中点「安装兼容服务」，按 macOS 提示确认。": "Choose Install service in the component and follow the macOS approval prompts.",
        "正在自动检测组件": "Checking for the component automatically",
        "已连接。返回盖盖，即可领取试用或开启合盖功能。": "Connected. Return to LidLid to claim your trial or enable closed-lid mode.",
        "完成安装与授权后，盖盖会自动识别，无需重新启动。": "LidLid will detect it after setup. No restart needed.",
        "已找到组件。打开并完成系统授权后，这里会自动更新。": "Component found. Open it and approve the service; this status will update automatically.",
        "无法打开，请使用下方安装帮助。": "Could not open it. Use the setup help below.",
        "下载已交给浏览器，请打开 DMG 并拖入应用程序。": "The download is open in your browser. Open the DMG and drag the app into Applications.",
        "返回盖盖": "Return to LidLid",
        "安装帮助": "Setup help",
        "开盖不休眠永久免费": "Open-lid keep-awake is always free",
        "合盖永久版已解锁": "Closed-lid lifetime access unlocked",
        "正在检查购买…": "Checking purchases…",
        "合盖试用至：": "Closed-lid trial ends: ",
        "合盖试用已结束": "Your closed-lid trial has ended",
        "合盖先试用，再决定": "Try closed-lid keep-awake first",
        "合盖试用 7 天。到期仅限制新会话，已开启的本次会话按原设置结束。永久版一次购买，不自动续费。合盖功能需免费兼容组件。": "Try closed-lid keep-awake for 7 days. Expiry blocks new sessions; your current session finishes as configured. Lifetime access is a one-time purchase, with no renewal. Closed-lid mode requires the free compatibility component.",
        "设置好免费兼容组件后，可开始合盖试用。": "Set up the free compatibility component before starting your closed-lid trial.",
        "免费试用合盖 7 天": "Try closed-lid mode free for 7 days",
        "永久解锁合盖 · ": "Unlock closed-lid access · ",
        "正在加载永久版价格…": "Loading lifetime price…",
        "恢复购买": "Restore purchases",
        "合盖永久解锁": "Closed-lid lifetime access",
        "请在 App Store 窗口中完成确认。": "Confirm in the App Store window.",
        "重新加载商品": "Reload products",
        "无法验证购买，请恢复购买或稍后重试。": "Couldn't verify the purchase. Restore purchases or try again later.",
        "购买正在等待批准，完成后将自动解锁。": "Purchase pending approval. Access will unlock when it completes.",
        "购买未完成，请稍后重试。": "Purchase wasn't completed. Please try again later.",
        "无法完成购买，请检查 App Store 连接后重试。": "Couldn't complete the purchase. Check your App Store connection and try again.",
        "没有可恢复的有效购买；已结束的试用不会重新开始。": "No active purchase to restore. An ended trial won't restart.",
        "无法恢复购买，请检查 App Store 连接后重试。": "Couldn't restore purchases. Check your App Store connection and try again.",
        "商店商品暂不可用，请稍后重试。": "Store products aren't available yet. Please try again later.",
        "盖盖：合盖与开盖不休眠已开启": "LidLid: Closed-lid and open-lid keep-awake are on",
        "开盖不休眠": "Keep awake with lid open",
        "屏幕仍可自动熄灭，合盖时暂停": "Display can sleep. Pauses when you close the lid.",
        "合盖或睡眠时暂停，开盖唤醒后恢复": "Paused while closed or asleep. Resumes on reopening and wake.",
        "盖盖：开盖不休眠已开启": "LidLid: Open-lid keep-awake is on",
        "无法读取合盖状态，开盖不休眠已关闭": "Lid readings unavailable. Open-lid keep-awake turned off.",
        "开盖不休眠连接超时，请重新开启": "Open-lid keep-awake timed out. Turn it on again.",
        "无法读取电量，开盖不休眠已关闭": "Battery readings unavailable. Open-lid keep-awake turned off.",
        "电量已降至 10%，开盖不休眠已关闭": "Battery reached 10%. Open-lid keep-awake turned off.",
        "温度过高，开盖不休眠已关闭": "Your Mac is too hot. Open-lid keep-awake turned off.",
        "正在连接兼容服务…": "Connecting to compatibility service…",
        "盖盖兼容组件": "LidLid Compatibility",
        "让合盖运行更可靠": "Reliable closed-lid sessions",
        "免费组件，由你在 macOS 中授权。仅在盖盖会话期间管理系统睡眠；开盖、退出或连接超时后恢复原设置。": "A free component approved by you in macOS. It manages system sleep during LidLid sessions and restores the original setting when you reopen the lid, quit, or the connection times out.",
        "请先安装并授权盖盖兼容组件": "Install and approve LidLid Compatibility first",
        "兼容组件已就绪": "Compatibility component ready",
        "请在系统设置中允许盖盖兼容组件": "Allow LidLid Compatibility in System Settings",
        "请先把兼容组件拖到应用程序文件夹": "Drag LidLid Compatibility to Applications first",
        "睡眠已恢复，可以移除兼容组件": "Sleep restored. You can remove the compatibility app.",
        "打开应用程序文件夹": "Open Applications",
        "安装兼容服务": "Install service",
        "打开系统设置": "Open System Settings",
        "刷新状态": "Refresh",
        "恢复睡眠并移除服务": "Restore sleep & remove service",
        "需要主动睡眠时，请先关闭盖盖。移除组件前，请先点“恢复睡眠并移除服务”。": "Turn LidLid off before choosing Sleep. Use Restore sleep & remove service before deleting this app.",
        "设置免费兼容组件": "Set up free compatibility component",
        "管理兼容组件": "Manage compatibility component",
        "请更新盖盖兼容组件": "Update LidLid Compatibility",
        "兼容组件暂时不可用，请重新打开组件检查": "Compatibility component unavailable. Open it to check its status.",
        "兼容组件响应超时，请保持开盖并检查组件": "Compatibility component timed out. Keep the lid open and check the component.",
        "兼容组件正在恢复睡眠，请保持开盖": "Restoring sleep. Keep the lid open.",
        "兼容组件正在移除，请重新安装后再试": "Compatibility service is being removed. Reinstall it before trying again.",
        "兼容组件未能确认睡眠设置，请稍后重试": "Could not confirm sleep settings. Try again.",
        "兼容组件会话已结束，请重新开启": "Compatibility session ended. Turn LidLid on again.",
        "睡眠设置被其他程序更改，本次已结束": "Another app changed sleep settings. This session has ended.",
        "兼容组件恢复记录版本不匹配，请联系支持": "Recovery record version mismatch. Contact support.",
        "请保持开盖，确认电量、温度和显示器状态后重试": "Keep the lid open and check battery, temperature and displays before trying again.",
        "电量、温度或用户状态改变，本次已结束": "Battery, temperature or user changed. This session has ended.",
        "无法读取系统睡眠设置，请稍后重试": "Could not read system sleep settings. Try again.",
        "系统睡眠设置超时，请保持开盖并重试": "Sleep setting request timed out. Keep the lid open and try again.",
        "系统拒绝兼容组件的睡眠设置": "macOS rejected the compatibility sleep setting",
        "兼容服务需要 macOS 管理员授权": "The compatibility service requires macOS administrator approval",
        "兼容组件恢复目录权限异常，请联系支持": "Recovery directory permissions are invalid. Contact support.",
        "无法读取兼容组件恢复记录": "Could not read the compatibility recovery record",
        "兼容组件恢复记录权限或格式异常，请联系支持": "Recovery record permissions or format are invalid. Contact support.",
        "无法保存兼容组件恢复记录": "Could not save the compatibility recovery record",
        "无法安全保存兼容组件恢复记录": "Could not safely save the compatibility recovery record",
        "无法清除兼容组件恢复记录": "Could not clear the compatibility recovery record",
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
        "退出盖盖": "Quit LidLid",
        "隐私政策": "Privacy Policy",
        "支持与帮助": "Help & Support",
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
