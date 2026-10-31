import AppKit
import IOKit
import LidOnceCore

/// A separate unprivileged process owns the global kernel flag. The UI keeps
/// its stdin pipe open and sends heartbeats. EOF, a hung UI, lid-open, battery,
/// thermal pressure, manual sleep, or an optional deadline all release the hold.
final class SessionAgent {
    let driver: PowerDriver
    private var session = OneShot()
    private var snapshot = Snapshot()
    private var ownsFlag = false
    private var restoring = false
    private var restoreAttempts = 0
    private var exiting = false
    private var lastHeartbeat = ProcessInfo.processInfo.systemUptime
    private var timer: Timer?
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private var lastPublished = Data()
    private var lastPowerOnBattery: Bool?
    private var lockFD: Int32 = -1
    private var lastKernelRefresh = ProcessInfo.processInfo.systemUptime

    init() throws {
        // A second UI/agent may never reset an existing session's global flag.
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LidOnce", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        lockFD = open(dir.appendingPathComponent("agent.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            throw PowerError(text: "另一个 LidOnce 会话正在运行")
        }
        driver = try PowerDriver()
    }
    func start() throws {
        guard driver.bool("AppleClamshellState") != nil else {
            throw PowerError(text: "这台 Mac 没有可读取的合盖传感器")
        }
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else { throw PowerError(text: "无法监听合盖事件") }
        IONotificationPortSetDispatchQueue(port, .main)
        let result = IOServiceAddInterestNotification(port, driver.root, kIOGeneralInterest, { context, _, type, argument in
            guard let context else { return }
            // kIOPMMessageClamshellStateChange = sys_iokit | sub_iokit_powermanagement | 0x100
            if type == 0xe0034100 {
                let agent = Unmanaged<SessionAgent>.fromOpaque(context).takeUnretainedValue()
                let closed = (UInt(bitPattern: argument) & 1) != 0
                agent.lidChanged(closed)
            }
        }, Unmanaged.passUnretained(self).toOpaque(), &notifier)
        guard result == kIOReturnSuccess else { throw PowerError(text: "合盖事件监听失败") }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshFlag()
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop("系统正在睡眠，本次已结束")
        })
        for code in [SIGTERM, SIGINT, SIGHUP] {
            signal(code, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: code, queue: .main)
            source.setEventHandler { [weak self] in self?.finish() }
            source.resume(); signals.append(source)
        }
        signal(SIGPIPE, SIG_IGN)
        // Blocking reads run on a background queue; all mutations stay on main.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while let line = readLine() {
                guard let data = line.data(using: .utf8), let command = try? JSONDecoder().decode(Command.self, from: data) else { continue }
                DispatchQueue.main.async { self?.receive(command) }
            }
            DispatchQueue.main.async { self?.finish() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    private func receive(_ command: Command) {
        lastHeartbeat = ProcessInfo.processInfo.systemUptime
        switch command.action {
        case "arm": arm(minutes: command.minutes ?? 0)
        case "stop": stop("已取消，恢复正常合盖睡眠")
        case "quit": finish()
        default: break
        }
    }
    private func arm(minutes: Int) {
        guard !ownsFlag, !restoring, !exiting else { return }
        do {
            #if !arch(arm64)
            throw PowerError(text: "此版本仅支持 Apple Silicon MacBook")
            #endif
            guard [0, 30, 60, 120, 240, 480].contains(minutes) else { throw PowerError(text: "无效的时长设置") }
            guard !conflictingApp() else { throw PowerError(text: "请先退出 Clamshell，避免两个软件同时控制合盖") }
            guard driver.bool("AppleClamshellState") == false else { throw PowerError(text: "请先打开电脑盖子") }
            guard try externalDisplayCount() == 0 else { throw PowerError(text: "请断开外接显示器后再启用") }
            guard driver.bool("SleepDisabled") == false else {
                throw PowerError(text: "其他程序正在接管睡眠，请先关闭它的防睡眠功能")
            }
            guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
                throw PowerError(text: "温度过高，冷却后再启用")
            }
            let battery = batteryReading()
            guard let percent = battery.percent else { throw PowerError(text: "无法读取电量，请稍后再试") }
            guard !battery.onBattery || percent > 10 else { throw PowerError(text: "电量不高于 10%，请接通电源") }
            snapshot.phase = .starting; snapshot.message = "正在确认合盖控制…"; snapshot.error = false; publish()
            try driver.holdAssertions()
            // Set ownership BEFORE calling; any failure rolls back even if the call partially applied.
            ownsFlag = true
            try driver.suppressLidSleep(true)
            lastKernelRefresh = ProcessInfo.processInfo.systemUptime
            EventLog.write("arm: selector12(true) accepted; minutes=\(minutes)")
            guard session.arm(now: ProcessInfo.processInfo.systemUptime, minutes: minutes, lidClosed: false) else {
                throw PowerError(text: "会话状态异常")
            }
            snapshot.message = "现在可以合盖，开盖后自动结束"
            snapshot.phase = .armed
            snapshot.deadline = minutes > 0 ? Date().timeIntervalSince1970 + Double(minutes * 60) : nil
            tick()
        } catch {
            if ownsFlag || driver.hasAssertions { stop(error.localizedDescription, error: true) }
            else { snapshot.phase = .off; snapshot.message = error.localizedDescription; snapshot.error = true; publish() }
        }
    }
    private func lidChanged(_ closed: Bool) {
        snapshot.lidClosed = closed
        guard ownsFlag, !restoring else { publish(); return }
        if session.observe(closed: closed) {
            EventLog.write("lid opened: consuming one-shot session")
            stop("本次已完成，下次合盖将正常睡眠"); return
        }
        if closed, snapshot.phase != .closed {
            EventLog.write("lid closed: one-shot session active")
            snapshot.phase = .closed
            snapshot.message = "合盖运行中 · 开盖即结束"
            // Display sleep is separate from system sleep. Never force a screen
            // wake or alter the user's lock/password preferences.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
        publish()
    }
    private func refreshFlag() {
        guard ownsFlag, !restoring else { return }
        do { try driver.suppressLidSleep(true) }
        catch { stop(error.localizedDescription, error: true) }
    }
    private func tick() {
        let battery = batteryReading()
        snapshot.battery = battery.percent; snapshot.onBattery = battery.onBattery
        snapshot.thermal = thermalLabel()
        snapshot.causesSleep = driver.bool("AppleClamshellCausesSleep")
        if restoring { restore(); return }
        if ownsFlag {
            if ProcessInfo.processInfo.systemUptime - lastHeartbeat > 12 { finish(); return }
            if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                stop("温度过高，已恢复正常睡眠", error: true); return
            }
            if battery.percent == nil { stop("电量读取中断，已恢复正常睡眠", error: true); return }
            if battery.onBattery && (battery.percent ?? 0) <= 10 { stop("电量已降至 10%，已恢复正常睡眠"); return }
            if session.expired(now: ProcessInfo.processInfo.systemUptime) { stop("达到设定时长，本次已结束"); return }
            do {
                if try externalDisplayCount() > 0 { stop("已连接外接屏，本次结束，由 macOS 管理睡眠"); return }
            } catch { stop(error.localizedDescription, error: true); return }
            guard let closed = driver.bool("AppleClamshellState") else {
                stop("合盖传感器读取中断，已恢复正常睡眠", error: true); return
            }
            lidChanged(closed)
            guard ownsFlag, !restoring else { return }
            // CausesSleep is a cached aggregate value. Apple's implementation
            // does NOT republish it when selector 12 changes its mask. It is
            // diagnostic data, never a read-back of our own hold or cleanup.
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastKernelRefresh >= 1 || lastPowerOnBattery != battery.onBattery {
                refreshFlag(); lastKernelRefresh = now
            }
        } else { snapshot.lidClosed = driver.bool("AppleClamshellState") }
        lastPowerOnBattery = battery.onBattery
        publish()
    }
    private func stop(_ message: String, error: Bool = false) {
        if ownsFlag { EventLog.write("stop: \(message)") }
        snapshot.message = message; snapshot.error = error
        session.reset(); snapshot.deadline = nil
        if ownsFlag || driver.hasAssertions {
            restoring = true; snapshot.phase = .restoring; restoreAttempts = 0; restore()
        } else { snapshot.phase = .off; publish(); if exiting { exit(0) } }
    }
    private func restore() {
        restoreAttempts += 1
        do {
            if ownsFlag { try driver.suppressLidSleep(false) }
            driver.releaseAssertions()
            guard !driver.hasAssertions else { throw PowerError(text: "等待防睡眠请求释放") }
            ownsFlag = false; restoring = false; snapshot.phase = .off
            EventLog.write("restore: selector12(false) accepted; assertions released")
            snapshot.causesSleep = driver.bool("AppleClamshellCausesSleep")
            publish()
            if exiting { exit(0) }
        } catch {
            if restoreAttempts > 12 {
                snapshot.message = "恢复尚未确认，正在重试。请保持开盖；必要时重启 Mac。"
                snapshot.error = true
            }
            publish()
        }
    }
    private func finish() {
        guard !exiting else { return }
        exiting = true
        stop("会话已结束，恢复正常睡眠")
    }
    private func publish() {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(snapshot), data != lastPublished else { return }
        lastPublished = data
        do { try FileHandle.standardOutput.write(contentsOf: data + Data([10])) }
        catch { if !exiting { finish() } }
    }
}
