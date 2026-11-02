import AppKit
import IOKit
import LidOnceCore
import LidOnceSystem
import LidLidServiceProtocol

/// Sandboxed session worker. The independently installed service owns a short
/// renewable lease; this process never changes persistent system sleep settings.
final class SessionAgent {
    let driver: PowerDriver
    private var session = OneShot()
    private var snapshot = Snapshot()
    private var ownsSession = false
    private let compatibility = CompatibilityClient()
    private var operationPending = false
    private var generation = 0
    private var lastCompatibilityCheck: TimeInterval = -10
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
    private var lockFD: Int32 = -1

    init() throws {
        // A second UI/agent may never take over an existing session.
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LidOnce", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        lockFD = open(dir.appendingPathComponent("agent.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            throw PowerError(text: "另一个盖盖会话正在运行")
        }
        driver = try PowerDriver()
        snapshot.agentPID = getpid()
        snapshot.sandboxContainer = NSHomeDirectory()
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
                self?.checkCompatibility()
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
        guard !ownsSession, !restoring, !exiting else { return }
        do {
            guard snapshot.compatibilityReady else { throw PowerError(text: snapshot.compatibilityMessage) }
            generation += 1
            if operationPending { compatibility.invalidate(); operationPending = false }
            #if !arch(arm64)
            throw PowerError(text: "此版本仅支持 Apple Silicon MacBook")
            #endif
            guard [0, 30, 60, 120, 240, 480].contains(minutes) else { throw PowerError(text: "无效的时长设置") }
            guard !conflictingApp() else { throw PowerError(text: "请先退出 Clamshell，避免两个软件同时控制合盖") }
            guard driver.bool("AppleClamshellState") == false else { throw PowerError(text: "请先打开电脑盖子") }
            guard try externalDisplayCount() == 0 else { throw PowerError(text: "请断开外接显示器后再启用") }
            guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
                throw PowerError(text: "温度过高，冷却后再启用")
            }
            let battery = batteryReading()
            guard let percent = battery.percent else { throw PowerError(text: "无法读取电量，请稍后再试") }
            guard !battery.onBattery || percent > 10 else { throw PowerError(text: "电量不高于 10%，请接通电源") }
            snapshot.phase = .starting; snapshot.message = "正在确认合盖控制…"; snapshot.error = false; publish()
            try driver.holdAssertions()
            ownsSession = true
            operationPending = true
            let token = generation
            compatibility.begin(minutes: minutes) { [weak self] result in
                guard let self, token == self.generation, !self.restoring else { return }
                self.operationPending = false
                switch result {
                case .success:
                    guard self.session.arm(now: ProcessInfo.processInfo.systemUptime, minutes: minutes, lidClosed: false) else {
                        self.stop("会话状态异常", error: true); return
                    }
                    EventLog.write("arm: compatibility lease confirmed; minutes=\(minutes)")
                    self.snapshot.compatibilityReady = true
                    self.snapshot.message = "现在可以合盖，开盖后自动结束"
                    self.snapshot.phase = .armed
                    self.snapshot.deadline = minutes > 0 ? Date().timeIntervalSince1970 + Double(minutes * 60) : nil
                    self.lastCompatibilityCheck = ProcessInfo.processInfo.systemUptime
                    self.tick()
                case .failure(let error): self.stop(error.localizedDescription, error: true)
                }
            }
        } catch {
            if ownsSession || driver.hasAssertions { stop(error.localizedDescription, error: true) }
            else { snapshot.phase = .off; snapshot.message = error.localizedDescription; snapshot.error = true; publish() }
        }
    }
    private func lidChanged(_ closed: Bool) {
        snapshot.lidClosed = closed
        guard ownsSession, !restoring else { publish(); return }
        if snapshot.phase == .starting {
            if closed { stop("请先打开电脑盖子", error: true) }
            return
        }
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
    private func checkCompatibility() {
        guard !operationPending, !restoring else { return }
        operationPending = true
        lastCompatibilityCheck = ProcessInfo.processInfo.systemUptime
        let token = generation
        if ownsSession {
            compatibility.renew { [weak self] result in
                guard let self, token == self.generation else { return }
                self.operationPending = false
                if case .failure(let error) = result { self.stop(error.localizedDescription, error: true) }
            }
        } else {
            compatibility.status { [weak self] result in
                guard let self, token == self.generation else { return }
                self.operationPending = false
                switch result {
                case .success(let status):
                    self.snapshot.compatibilityReady = !status.recoveryPending && !status.active
                    self.snapshot.compatibilityMessage = status.recoveryPending ? "兼容组件正在恢复睡眠，请保持开盖" : "兼容组件已就绪"
                case .failure(let error):
                    self.snapshot.compatibilityReady = false
                    self.snapshot.compatibilityMessage = error.localizedDescription
                }
                self.publish()
            }
        }
    }
    private func tick() {
        let battery = batteryReading()
        snapshot.battery = battery.percent; snapshot.onBattery = battery.onBattery
        snapshot.thermal = thermalLabel()
        snapshot.causesSleep = driver.bool("AppleClamshellCausesSleep")
        if restoring { restore(); return }
        if ownsSession {
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
            guard ownsSession, !restoring else { return }
        } else { snapshot.lidClosed = driver.bool("AppleClamshellState") }
        if ProcessInfo.processInfo.systemUptime - lastCompatibilityCheck >= CompatibilityService.renewalSeconds {
            checkCompatibility()
        }
        publish()
    }
    private func stop(_ message: String, error: Bool = false) {
        if ownsSession { EventLog.write("stop: \(message)") }
        generation += 1
        if operationPending { compatibility.invalidate() }
        operationPending = false
        snapshot.message = message; snapshot.error = error
        session.reset(); snapshot.deadline = nil
        if ownsSession || driver.hasAssertions {
            restoring = true; snapshot.phase = .restoring; restoreAttempts = 0; restore()
        } else { snapshot.phase = .off; publish(); if exiting { exit(0) } }
    }
    private func restore() {
        guard !operationPending else { return }
        operationPending = true
        restoreAttempts += 1
        let token = generation
        compatibility.end { [weak self] _ in
            guard let self, token == self.generation else { return }
            self.compatibility.status { [weak self] result in
                guard let self, token == self.generation else { return }
                self.operationPending = false
                self.driver.releaseAssertions()
                let serviceConfirmed: Bool
                if case .success(let status) = result { serviceConfirmed = !status.active && !status.recoveryPending }
                else { serviceConfirmed = false }
                // The service only starts from SleepDisabled=false. A direct
                // kernel read of that exact global setting can also confirm
                // restoration if the service connection is unavailable.
                if (serviceConfirmed || self.driver.bool("SleepDisabled") == false), !self.driver.hasAssertions {
                    self.ownsSession = false; self.restoring = false; self.snapshot.phase = .off
                    self.snapshot.compatibilityReady = serviceConfirmed
                    EventLog.write("restore: original sleep setting confirmed; service=\(serviceConfirmed); assertions released")
                    self.publish()
                    if self.exiting { exit(0) }
                } else {
                    // Invalidating the old connection also revokes its lease.
                    // Never report Off before the service confirms restoration.
                    self.compatibility.invalidate()
                    if self.restoreAttempts > 3 {
                        self.snapshot.message = "兼容组件正在恢复睡眠，请保持开盖"
                        self.snapshot.error = true
                    }
                    self.publish()
                }
            }
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
