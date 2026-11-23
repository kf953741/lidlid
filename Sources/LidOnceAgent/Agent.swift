import AppKit
import IOKit
import LidOnceCore
import LidOnceSystem
import LidLidServiceProtocol

/// Sandboxed session worker. The independently installed service owns a short
/// renewable lease; this process never changes persistent system sleep settings.
final class SessionAgent {
    let driver: PowerDriver
    private var hasLidSensor = true
    private var session = OneShot()
    private let openLid = OpenLidSession(assertion: OpenLidAssertion())
    private let displayAwake = OpenLidSession(assertion: OpenLidAssertion(scope: .display))
    private var systemSleeping = false
    private var snapshot = Snapshot()
    private var ownsSession = false
    private let compatibility = CompatibilityClient()
    private var operationPending = false
    private var generation = 0
    private var lastCompatibilityCheck: TimeInterval = -10
    private var lastConfirmedRenewal: TimeInterval = 0
    private var transientRenewFailures = 0
    private var restoring = false
    private var restoreAttempts = 0
    private var exiting = false
    private var lastHeartbeat = ProcessInfo.processInfo.systemUptime
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var appNapActivity: NSObjectProtocol?
    private var displaySleepProcess: Process?
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private var lastPublished: Snapshot?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
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
    deinit {
        if let activity = appNapActivity { ProcessInfo.processInfo.endActivity(activity) }
    }

    func start() throws {
        hasLidSensor = driver.bool("AppleClamshellState") != nil
        snapshot.hasLidSensor = hasLidSensor
        if hasLidSensor {
            try registerLidNotifications()
        } else {
            snapshot.message = "这台 Mac 没有可读取的合盖传感器"
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                if name == NSWorkspace.didWakeNotification {
                    self.systemSleeping = false
                    // Prevent spurious heartbeat timeout right after waking from sleep.
                    self.lastHeartbeat = ProcessInfo.processInfo.systemUptime
                }
                if self.hasLidSensor { self.checkCompatibility() }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.systemSleeping = true
            let battery = batteryReading()
            let lidClosed = self.effectiveLidClosed(self.snapshot.lidClosed)
            self.updateOpenLid(battery: battery, lidClosed: lidClosed)
            self.updateDisplayAwake(battery: battery, lidClosed: lidClosed)
            self.stop("系统正在睡眠，本次已结束")
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
        syncTimer()
        tick()
    }
    private func registerLidNotifications() throws {
        guard notificationPort == nil else { return }
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
        guard result == kIOReturnSuccess else {
            IONotificationPortDestroy(port)
            notificationPort = nil
            throw PowerError(text: "合盖事件监听失败")
        }
    }
    private func effectiveLidClosed(_ raw: Bool?) -> Bool? {
        if let raw { return raw }
        return hasLidSensor ? nil : false
    }
    private var needsFastPolling: Bool {
        ownsSession || restoring || exiting
            || openLid.requested || openLid.active
            || displayAwake.requested || displayAwake.active
    }
    /// Poll at 1 Hz while active (0.5 s while restoring) because hardware lid
    /// notifications arrive immediately through IONotificationPort, and back off
    /// to 3 s when completely idle.
    private func syncTimer() {
        let active = needsFastPolling
        if active, appNapActivity == nil {
            appNapActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Keep LidLid worker lease renewals responsive"
            )
        } else if !active, let activity = appNapActivity {
            ProcessInfo.processInfo.endActivity(activity)
            appNapActivity = nil
        }
        let desired: TimeInterval = restoring ? 0.5 : (active ? 1.0 : 3.0)
        guard desired != timerInterval || timer == nil else { return }
        timer?.invalidate()
        timerInterval = desired
        let scheduled = Timer(timeInterval: desired, repeats: true) { [weak self] _ in self?.tick() }
        scheduled.tolerance = desired * 0.2
        RunLoop.main.add(scheduled, forMode: .common)
        timer = scheduled
    }
    private func receive(_ command: Command) {
        lastHeartbeat = ProcessInfo.processInfo.systemUptime
        switch command.action {
        case "arm": arm(minutes: command.minutes ?? 0)
        case "open-awake-on": setOpenLid(true)
        case "open-awake-off": setOpenLid(false)
        case "display-awake-on":
            if let minutes = command.minutes, let duration = DisplayAwakeDuration(rawValue: minutes) {
                startDisplayAwake(duration)
            }
        case "display-awake-off":
            stopDisplayAwake()
            publish()
        case "clear-error":
            if !ownsSession && !restoring && snapshot.error {
                snapshot.error = false
                snapshot.message = hasLidSensor ? Snapshot().message : "这台 Mac 没有可读取的合盖传感器"
                publish()
            }
        case "check-compatibility":
            if hasLidSensor { checkCompatibility() }
        case "stop": stop("已取消，恢复正常合盖睡眠")
        case "quit": finish()
        default: break
        }
    }
    private func setOpenLid(_ enabled: Bool) {
        guard !exiting else { return }
        let battery = batteryReading()
        let lidClosed = effectiveLidClosed(driver.bool("AppleClamshellState"))
        do {
            snapshot.openAwakeError = false
            if enabled, let message = openLidSafetyIssue(battery: battery) { throw PowerError(text: message) }
            try openLid.setEnabled(enabled, now: ProcessInfo.processInfo.systemUptime,
                                   lidClosed: lidClosed, systemSleeping: systemSleeping)
            EventLog.write("open-lid idle protection requested=\(enabled); bounded assertion=30s")
            updateOpenLid(battery: battery, lidClosed: lidClosed)
        } catch { failOpenLid(error.localizedDescription) }
        publish()
    }
    private func failOpenLid(_ message: String) {
        try? openLid.disable()
        snapshot.openAwakeError = true
        snapshot.openAwakeMessage = message
        snapshot.openAwakeRequested = openLid.requested
        snapshot.openAwakeActive = openLid.active
    }
    private func openLidSafetyIssue(battery: BatteryReading) -> String? {
        if hasLidSensor {
            if battery.percent == nil { return "无法读取电量，开盖不休眠已关闭" }
            if battery.onBattery && battery.percent! <= 10 { return "电量已降至 10%，开盖不休眠已关闭" }
        } else if battery.onBattery, let percent = battery.percent, percent <= 10 {
            return "电量已降至 10%，开盖不休眠已关闭"
        }
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            return "温度过高，开盖不休眠已关闭"
        }
        return nil
    }
    private func updateOpenLid(battery: BatteryReading, lidClosed: Bool?) {
        if (openLid.requested || openLid.active), let message = openLidSafetyIssue(battery: battery) {
            failOpenLid(message); return
        }
        do {
            try openLid.tick(now: ProcessInfo.processInfo.systemUptime,
                             lidClosed: lidClosed, systemSleeping: systemSleeping)
            snapshot.openAwakeRequested = openLid.requested
            snapshot.openAwakeActive = openLid.active
            if !snapshot.openAwakeError {
                snapshot.openAwakeMessage = openLid.requested && !openLid.active
                    ? "合盖或睡眠时暂停，开盖唤醒后恢复" : "屏幕仍可自动熄灭，合盖时暂停"
            }
        } catch { failOpenLid(error.localizedDescription) }
    }
    private func startDisplayAwake(_ duration: DisplayAwakeDuration) {
        guard !exiting, !displayAwake.requested, !displayAwake.active else { return }
        defer { publish() }
        let battery = batteryReading()
        guard effectiveLidClosed(driver.bool("AppleClamshellState")) == false, !systemSleeping else {
            stopDisplayAwake(error: "请先打开电脑盖子"); return
        }
        guard openLidSafetyIssue(battery: battery) == nil else {
            stopDisplayAwake(error: "电量或温度触发保护，屏幕常亮已关闭"); return
        }
        do {
            try displayAwake.setEnabled(true, now: ProcessInfo.processInfo.systemUptime,
                                       lidClosed: false, displayDuration: duration)
            syncDisplayAwake()
        } catch {
            EventLog.write("display keep-awake: \(error.localizedDescription)")
            stopDisplayAwake(error: "无法保持屏幕常亮，请重试")
        }
    }
    private func updateDisplayAwake(battery: BatteryReading, lidClosed: Bool?) {
        guard displayAwake.requested || displayAwake.active else { return }
        guard !displayAwake.requested || openLidSafetyIssue(battery: battery) == nil else {
            stopDisplayAwake(error: "电量或温度触发保护，屏幕常亮已关闭"); return
        }
        do {
            try displayAwake.tick(now: ProcessInfo.processInfo.systemUptime,
                                  lidClosed: lidClosed, systemSleeping: systemSleeping)
            syncDisplayAwake()
        } catch {
            EventLog.write("display keep-awake: \(error.localizedDescription)")
            stopDisplayAwake(error: "屏幕常亮已中断，请重新开启")
        }
    }
    private func stopDisplayAwake(error: String? = nil) {
        do {
            try displayAwake.disable()
            syncDisplayAwake(error: error)
        } catch {
            EventLog.write("display keep-awake cleanup: \(error.localizedDescription)")
            syncDisplayAwake(error: "正在结束屏幕常亮…")
        }
    }
    private func syncDisplayAwake(error: String? = nil) {
        snapshot.displayAwake = DisplayAwakeStatus(active: displayAwake.active,
                                                   requested: displayAwake.requested,
                                                   deadline: displayAwake.deadline, error: error)
    }
    private func arm(minutes: Int) {
        guard !ownsSession, !restoring, !exiting else { return }
        do {
            guard hasLidSensor else { throw PowerError(text: "这台 Mac 没有可读取的合盖传感器") }
            guard snapshot.compatibilityReady else { throw PowerError(text: snapshot.compatibilityMessage) }
            generation += 1
            if operationPending { compatibility.invalidate(); operationPending = false }
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
                    self.lastConfirmedRenewal = self.lastCompatibilityCheck
                    self.transientRenewFailures = 0
                    self.tick()
                case .failure(let error): self.stop(error.localizedDescription, error: true)
                }
            }
        } catch {
            if ownsSession { stop(error.localizedDescription, error: true) }
            else { snapshot.phase = .off; snapshot.message = error.localizedDescription; snapshot.error = true; publish() }
        }
    }
    private func lidChanged(_ closed: Bool) {
        snapshot.lidClosed = closed
        let battery = batteryReading()
        updateOpenLid(battery: battery, lidClosed: closed)
        updateDisplayAwake(battery: battery, lidClosed: closed)
        handleClosedLidObservation(closed)
        publish()
    }
    private func handleClosedLidObservation(_ closed: Bool) {
        guard ownsSession, !restoring else { return }
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
            // Display sleep is separate from system sleep. Retain process until exit.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] finished in
                DispatchQueue.main.async {
                    if self?.displaySleepProcess === finished { self?.displaySleepProcess = nil }
                }
            }
            displaySleepProcess = process
            do { try process.run() } catch { displaySleepProcess = nil }
        }
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
                switch result {
                case .success:
                    self.lastConfirmedRenewal = ProcessInfo.processInfo.systemUptime
                    self.transientRenewFailures = 0
                case .failure(let error):
                    let message = error.localizedDescription
                    let elapsed = ProcessInfo.processInfo.systemUptime - self.lastConfirmedRenewal
                    // A single transient pmset -g timeout during lock-screen or heavy load
                    // leaves the 30-second daemon lease intact; retry quickly within budget.
                    if message == "系统睡眠设置超时，请保持开盖并重试",
                       self.transientRenewFailures < 2,
                       elapsed < CompatibilityService.leaseSeconds - 8 {
                        self.transientRenewFailures += 1
                        EventLog.write("renew: transient pmset timeout (attempt \(self.transientRenewFailures)); retrying within lease")
                        self.lastCompatibilityCheck = ProcessInfo.processInfo.systemUptime - CompatibilityService.renewalSeconds + 1.0
                    } else {
                        self.stop(message, error: true)
                    }
                }
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
        if (ownsSession || openLid.requested || openLid.active || displayAwake.requested || displayAwake.active),
           ProcessInfo.processInfo.systemUptime - lastHeartbeat > 12, !exiting {
            finish(); return
        }
        // Sample battery, thermal, lid and SleepDisabled once per tick to avoid redundant IPC.
        let battery = batteryReading()
        let rawLidClosed = driver.bool("AppleClamshellState")
        if !hasLidSensor && rawLidClosed != nil {
            // If an early startup probe missed the MacBook lid sensor, promote immediately.
            hasLidSensor = true
            snapshot.hasLidSensor = true
            if !snapshot.error && snapshot.message == "这台 Mac 没有可读取的合盖传感器" {
                snapshot.message = Snapshot().message
            }
            try? registerLidNotifications()
        }
        let effectiveLid = effectiveLidClosed(rawLidClosed)
        snapshot.battery = battery.percent; snapshot.onBattery = battery.onBattery
        snapshot.thermal = thermalLabel()
        snapshot.causesSleep = driver.bool("AppleClamshellCausesSleep")
        snapshot.lidClosed = rawLidClosed
        snapshot.sleepDisabled = driver.bool("SleepDisabled")
        updateOpenLid(battery: battery, lidClosed: effectiveLid)
        updateDisplayAwake(battery: battery, lidClosed: effectiveLid)
        if exiting && !ownsSession && !restoring && !openLid.active && !displayAwake.active { publish(); exit(0) }
        if restoring { restore(); return }
        if ownsSession {
            if conflictingApp() {
                stop("请先退出 Clamshell，避免两个软件同时控制合盖", error: true); return
            }
            if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                stop("温度过高，已恢复正常睡眠", error: true); return
            }
            if battery.percent == nil { stop("电量读取中断，已恢复正常睡眠", error: true); return }
            if battery.onBattery && (battery.percent ?? 0) <= 10 { stop("电量已降至 10%，已恢复正常睡眠"); return }
            if session.expired(now: ProcessInfo.processInfo.systemUptime) { stop("达到设定时长，本次已结束"); return }
            do {
                if try externalDisplayCount() > 0 { stop("已连接外接屏，本次结束，由 macOS 管理睡眠"); return }
            } catch { stop(error.localizedDescription, error: true); return }
            guard let closed = rawLidClosed else {
                stop("合盖传感器读取中断，已恢复正常睡眠", error: true); return
            }
            handleClosedLidObservation(closed)
            guard ownsSession, !restoring else { return }
        }
        if hasLidSensor, ProcessInfo.processInfo.systemUptime - lastCompatibilityCheck >= CompatibilityService.renewalSeconds {
            checkCompatibility()
        }
        syncTimer()
        publish()
    }
    private func stop(_ message: String, error: Bool = false) {
        if ownsSession { EventLog.write("stop: \(message)") }
        generation += 1
        transientRenewFailures = 0
        if operationPending { compatibility.invalidate() }
        operationPending = false
        snapshot.message = message; snapshot.error = error
        session.reset(); snapshot.deadline = nil
        if ownsSession {
            restoring = true; snapshot.phase = .restoring; restoreAttempts = 0; restore()
        } else { snapshot.phase = .off; publish(); if exiting && !openLid.active && !displayAwake.active { exit(0) } }
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
                // Authoritative XPC status takes precedence: never report Off
                // while the daemon still reports active or recoveryPending.
                let confirmed: Bool
                let serviceReady: Bool
                switch result {
                case .success(let status):
                    confirmed = !status.active && !status.recoveryPending
                    serviceReady = confirmed
                case .failure:
                    confirmed = self.driver.bool("SleepDisabled") == false
                    serviceReady = false
                }
                if confirmed {
                    self.ownsSession = false; self.restoring = false; self.snapshot.phase = .off
                    self.snapshot.compatibilityReady = serviceReady
                    self.snapshot.sleepDisabled = self.driver.bool("SleepDisabled")
                    EventLog.write("restore: original sleep setting confirmed; service=\(serviceReady)")
                    self.publish()
                    if self.exiting && !self.openLid.active && !self.displayAwake.active { exit(0) }
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
        stopDisplayAwake()
        do { try openLid.disable() } catch { failOpenLid(error.localizedDescription) }
        snapshot.openAwakeRequested = openLid.requested
        snapshot.openAwakeActive = openLid.active
        stop("会话已结束，恢复正常睡眠")
    }
    private func publish() {
        syncTimer()
        guard snapshot != lastPublished, let data = try? encoder.encode(snapshot) else { return }
        lastPublished = snapshot
        do { try FileHandle.standardOutput.write(contentsOf: data + Data([10])) }
        catch { if !exiting { finish() } }
    }
}
