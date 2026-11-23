import AppKit
import SwiftUI
import Combine
import ServiceManagement
import LidOnceCore
import LidOnceSystem

enum ClosedLidAction: Equatable {
    case checking, unsupportedMac, setup, tryFree, unlock, toggle
}

extension AppAppearance {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppModel: ObservableObject {
    private static let allowedMaximumMinutes: Set<Int> = [0, 30, 60, 120, 240, 480]
    let store = StoreAccessManager()
    private var storeChanges: AnyCancellable?
    @Published var state = Snapshot()
    @Published var connected = false
    @Published var conflict = conflictingApp()
    @Published var conflictQuitHint = false
    @Published var copiedRecoveryCommand = false
    @Published var options = false
    @Published var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            changed?()
        }
    }
    @Published var appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? "") ?? .system {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
            changed?()
        }
    }
    @Published var maximumMinutes: Int = {
        let saved = UserDefaults.standard.integer(forKey: "maximumMinutes")
        return allowedMaximumMinutes.contains(saved) ? saved : 0
    }() {
        didSet {
            let valid = Self.allowedMaximumMinutes.contains(maximumMinutes) ? maximumMinutes : 0
            if valid != maximumMinutes { maximumMinutes = valid; return }
            UserDefaults.standard.set(valid, forKey: "maximumMinutes")
        }
    }
    @Published var displayDuration: DisplayAwakeDuration = {
        guard UserDefaults.standard.object(forKey: "displayAwakeMinutes") != nil else { return .halfHour }
        return DisplayAwakeDuration(rawValue: UserDefaults.standard.integer(forKey: "displayAwakeMinutes")) ?? .halfHour
    }() {
        didSet { UserDefaults.standard.set(displayDuration.rawValue, forKey: "displayAwakeMinutes") }
    }
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginMessage: String?
    var isPopoverShown = false
    var changed: (() -> Void)?
    var readyToQuit: (() -> Void)?
    var showCompatibilitySetup: (() -> Void)?
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var buffer = Data()
    private var heartbeat: Timer?
    private var quitTimeout: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectAttempts = 0
    private var agentGeneration = 0
    private let writeQueue = DispatchQueue(label: "dev.kf.lidonce.agent-stdin", qos: .userInitiated)
    private var quitting = false
    private var requestedArm = false
    private let repairClient = CompatibilityClient()
    private var checkingRepair = false
    private var repairTimer: Timer?
    private var appNapActivity: NSObjectProtocol?

    deinit {
        if let activity = appNapActivity { ProcessInfo.processInfo.endActivity(activity) }
    }

    init() {
        storeChanges = store.objectWillChange.sink { [weak self] _ in
            // Published notifications precede mutation; check access after it.
            DispatchQueue.main.async {
                guard let self else { return }
                self.objectWillChange.send()
                // Access changes refresh the UI, never interrupt an accepted
                // one-shot session or the permanently free open-lid mode.
                self.changed?()
            }
        }
        store.start()
    }

    var busy: Bool { state.phase != .off }
    var openAwakeEnabled: Bool { state.openAwakeRequested || state.openAwakeActive }
    var displayAwakeEnabled: Bool { state.displayAwake?.active == true }
    var anySessionActive: Bool { busy || openAwakeEnabled || displayAwakeEnabled }
    var sleepStuckDisabled: Bool {
        state.phase == .off && !state.compatibilityReady && state.sleepDisabled == true
    }
    var canReconnect: Bool { !connected && process == nil && !quitting && state.phase == .off }
    var menuState: GuardianMenuState {
        GuardianMenuState(closedLidEnabled: enabled, openLidEnabled: openAwakeEnabled)
    }
    var canToggleOpenAwake: Bool { connected && !quitting && !(!state.openAwakeRequested && state.openAwakeActive) }
    var canToggleDisplayAwake: Bool {
        connected && !quitting && (displayAwakeEnabled
            ? state.displayAwake?.requested == true
            : (!state.hasLidSensor || state.lidClosed == false))
    }
    var menuLabel: String {
        let lidStatus = text(GuardianMenuSymbol.label(menuState))
        guard displayAwakeEnabled else { return lidStatus }
        return menuState == .off ? text("盖盖：屏幕常亮已开启")
            : "\(lidStatus) · \(text("屏幕常亮"))"
    }
    // The one-shot needs armed/closed internally; the person sees a single on state.
    var enabled: Bool { state.phase == .armed || state.phase == .closed || state.phase == .restoring }
    var changing: Bool { state.phase == .starting || state.phase == .restoring }
    var canToggle: Bool {
        connected && state.hasLidSensor && !changing
            && (enabled || store.allowsStartingClosedLidSession)
            && (!conflict || enabled)
            && (enabled || state.compatibilityReady)
    }
    var closedLidAction: ClosedLidAction {
        if busy { return .toggle }
        if !connected { return .checking }
        if !state.hasLidSensor { return .unsupportedMac }
        if !state.compatibilityReady { return .setup }
        guard store.isStoreEdition else { return .toggle }
        switch store.access {
        case .loading: return .checking
        case .locked: return .tryFree
        case .expired: return .unlock
        case .trial, .lifetime: return .toggle
        }
    }
    var text: AppText { AppText(language: language) }
    var brandName: String { text("盖盖") }
    var detail: String {
        if state.phase == .off && !state.error && state.message != Snapshot().message {
            return text(state.message)
        }
        return text(state.phase == .off ? "开启后，合盖时任务继续。" : "再次开盖时结束。")
    }
    var durationLabel: String { text.duration(maximumMinutes) }
    var title: String {
        switch state.phase {
        case .off: return text("已关闭")
        case .starting: return text("正在开启…")
        case .armed, .closed: return text("可以合盖")
        case .restoring: return text("正在关闭…")
        }
    }
    func launchAgent() {
        guard process == nil, !quitting else { return }
        reconnectWorkItem?.cancel(); reconnectWorkItem = nil
        agentGeneration += 1
        let generation = agentGeneration
        buffer.removeAll(keepingCapacity: true)
        let child = AgentProcess.make(), stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        input = stdin; output = stdout; process = child
        do {
            try child.run()
            // Only the agent may own the read end; a UI crash must cause EOF.
            try? stdin.fileHandleForReading.close()
            try? stdout.fileHandleForWriting.close()
        } catch {
            process = nil; input = nil; output = nil
            state.error = true; state.message = "无法启动合盖进程：\(error.localizedDescription)"
            scheduleReconnectIfAppropriate()
            changed?()
            return
        }
        let readHandle = stdout.fileHandleForReading
        // Serial stdout reader guarantees every snapshot written before exit
        // reaches main FIFO before agentEnded(generation:) executes.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                let data = readHandle.availableData
                if data.isEmpty { break }
                DispatchQueue.main.async { self?.consume(data, generation: generation) }
            }
            child.waitUntilExit()
            DispatchQueue.main.async { self?.agentEnded(generation: generation) }
        }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.send(Command("ping"))
            if self.busy || self.isPopoverShown {
                self.conflict = conflictingApp()
                if !self.conflict { self.conflictQuitHint = false }
            }
        }
        timer.tolerance = 0.2
        heartbeat = timer
        // Native menus use an event-tracking run-loop mode. Keep the heartbeat
        // running while a duration or language menu is open.
        RunLoop.main.add(timer, forMode: .common)
    }
    func reconnect() {
        guard canReconnect else { return }
        reconnectAttempts = 0
        state.error = false
        state.message = "正在连接盖盖…"
        changed?()
        launchAgent()
    }
    /// Prevent macOS App Nap from throttling the 2-second heartbeat timer when
    /// the screen locks during an active session, without holding any system or
    /// display sleep assertion in the UI process.
    private func syncAppNapActivity() {
        let shouldGuard = anySessionActive || requestedArm
        if shouldGuard, appNapActivity == nil {
            appNapActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Keep LidLid session heartbeat responsive"
            )
        } else if !shouldGuard, let activity = appNapActivity {
            ProcessInfo.processInfo.endActivity(activity)
            appNapActivity = nil
        }
    }
    private func consume(_ data: Data, generation: Int) {
        guard generation == agentGeneration, process != nil, !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
            guard let update = try? JSONDecoder().decode(Snapshot.self, from: line) else { continue }
            state = update; connected = true
            // Only reset backoff after a healthy worker startup, not a fatal exit snapshot.
            if !update.error && update.agentPID != nil { reconnectAttempts = 0 }
            if update.phase == .off { requestedArm = false }
            syncAppNapActivity()
            changed?()
            if quitting && !anySessionActive { send(Command("quit")) }
        }
    }
    func send(_ command: Command) {
        guard store.permits(command) else { return }
        guard process?.isRunning == true, let handle = input?.fileHandleForWriting,
              let data = try? JSONEncoder().encode(command) else { return }
        let payload = data + Data([10])
        writeQueue.async {
            try? handle.write(contentsOf: payload)
        }
    }
    func clearTransientError() {
        guard connected, state.phase == .off, state.error, !sleepStuckDisabled else { return }
        state.error = false
        state.message = state.hasLidSensor ? Snapshot().message : "这台 Mac 没有可读取的合盖传感器"
        send(Command("clear-error"))
        changed?()
    }
    func copyRecoveryCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("sudo pmset -a disablesleep 0", forType: .string)
        copiedRecoveryCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.copiedRecoveryCommand = false
        }
    }
    func toggle() {
        conflict = conflictingApp()
        guard connected, state.hasLidSensor, state.phase != .starting, state.phase != .restoring else { return }
        if busy { send(Command("stop")) }
        else if !conflict, store.allowsStartingClosedLidSession {
            requestedArm = true
            syncAppNapActivity()
            send(Command("arm", minutes: maximumMinutes))
        }
    }
    func setOpenAwake(_ enabled: Bool) {
        guard canToggleOpenAwake else { return }
        send(Command(enabled ? "open-awake-on" : "open-awake-off"))
    }
    func setDisplayAwake(_ enabled: Bool, duration: DisplayAwakeDuration) {
        guard canToggleDisplayAwake else { return }
        send(enabled ? Command("display-awake-on", minutes: duration.rawValue) : Command("display-awake-off"))
    }
    func quit() {
        quitting = true
        reconnectWorkItem?.cancel(); reconnectWorkItem = nil
        if process?.isRunning == true {
            send(Command("quit"))
            quitTimeout?.invalidate()
            // Bounded quit safeguard so a stalled worker can never block macOS logout/shutdown.
            let timeout = Timer(timeInterval: 6, repeats: false) { [weak self] _ in
                guard let self else { return }
                if let child = self.process, child.isRunning {
                    // SIGKILL ensures a stuck worker releases agent.lock and its XPC peer immediately.
                    kill(child.processIdentifier, SIGKILL)
                }
                self.repairTimer?.invalidate(); self.repairTimer = nil
                self.readyToQuit?()
            }
            RunLoop.main.add(timeout, forMode: .common)
            quitTimeout = timeout
        } else {
            readyToQuit?()
        }
    }
    private func agentEnded(generation: Int) {
        guard generation == agentGeneration else { return }
        heartbeat?.invalidate(); heartbeat = nil
        connected = false; process = nil; input = nil; output = nil
        state.displayAwake = nil  // macOS releases this process-owned assertion on exit.
        // The worker's XPC disconnect revokes its lease. Confirm recovery via
        // the independently running service before showing Off.
        if anySessionActive || requestedArm {
            state.phase = .restoring; state.error = true
            state.message = "合盖进程意外结束，正在恢复睡眠…"
            repairTimer?.invalidate()
            repairTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.repair() }
            RunLoop.main.add(repairTimer!, forMode: .common)
            repair()
        } else if quitting {
            quitTimeout?.invalidate(); quitTimeout = nil
            readyToQuit?()
        } else {
            state.error = true
            if state.message == Snapshot().message || state.message.isEmpty {
                state.message = "合盖进程已结束，请重新打开盖盖"
            }
            scheduleReconnectIfAppropriate()
        }
        syncAppNapActivity()
        changed?()
    }
    private func scheduleReconnectIfAppropriate() {
        guard !quitting, reconnectAttempts < 3 else { return }
        let delays: [TimeInterval] = [1.0, 3.0, 6.0]
        let delay = delays[min(reconnectAttempts, delays.count - 1)]
        reconnectAttempts += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.canReconnect else { return }
            self.launchAgent()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func repair() {
        guard !checkingRepair else { return }
        checkingRepair = true
        repairClient.status { [weak self] result in
            guard let self else { return }
            self.checkingRepair = false
            let confirmed: Bool
            switch result {
            case .success(let status): confirmed = !status.active && !status.recoveryPending
            case .failure: confirmed = (try? PowerDriver().bool("SleepDisabled")) == false
            }
            if confirmed {
                EventLog.write("parent recovery: original sleep setting confirmed after agent exit")
                self.repairTimer?.invalidate(); self.repairTimer = nil
                self.state.phase = .off; self.state.error = true
                self.state.openAwakeRequested = false; self.state.openAwakeActive = false
                self.state.message = "意外退出后已恢复睡眠，请重新打开盖盖"
                self.requestedArm = false
                self.syncAppNapActivity()
                if self.quitting {
                    self.quitTimeout?.invalidate(); self.quitTimeout = nil
                    self.readyToQuit?()
                } else {
                    self.scheduleReconnectIfAppropriate()
                }
            } else { self.state.message = "兼容组件正在恢复睡眠，请保持开盖" }
            self.changed?()
        }
    }
    func openCompatibility() {
        showCompatibilitySetup?()
    }
    func exitReference() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.rathonyi.clamshell")
        var requested = false
        for app in apps {
            if app.terminate() { requested = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.conflict = conflictingApp()
            // App Sandbox blocks terminating third-party apps; guide user when blocked.
            self.conflictQuitHint = self.conflict && !requested
        }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginMessage = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置 → 登录项中允许盖盖" : nil
        } catch { loginEnabled = SMAppService.mainApp.status == .enabled; loginMessage = error.localizedDescription }
    }
    func refreshSystemState() {
        conflict = conflictingApp()
        if !conflict { conflictQuitHint = false }
        loginEnabled = SMAppService.mainApp.status == .enabled
        if state.phase == .off {
            state.sleepDisabled = try? PowerDriver().bool("SleepDisabled")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private static let reopenNotification = Notification.Name("dev.kf.lidonce.reopen")
    let model = AppModel()
    private var status: NSStatusItem!
    private let popover = NSPopover()
    private let compatibilitySetup = CompatibilitySetupPresenter()
    private var allowsTermination = false
    private var reopenObserver: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != getpid() }) {
            DistributedNotificationCenter.default().postNotificationName(
                Self.reopenNotification, object: nil, userInfo: nil, deliverImmediately: true
            )
            existing.activate()
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        reopenObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.reopenNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.show()
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = status.button {
            button.target = self; button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(model.brandName)
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.appearance = model.appearance.nsAppearance
        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        model.store.confirmation.willPresent = { [weak self] in self?.popover.performClose(nil) }
        model.store.confirmation.didDismiss = { [weak self] in self?.show() }
        compatibilitySetup.willPresent = { [weak self] in self?.popover.performClose(nil) }
        compatibilitySetup.didDismiss = { [weak self] in self?.show() }
        model.showCompatibilitySetup = { [weak self] in
            guard let self else { return }
            self.compatibilitySetup.show(model: self.model)
        }
        model.changed = { [weak self] in self?.updateIcon() }
        model.readyToQuit = { [weak self] in
            self?.allowsTermination = true
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        model.launchAgent(); updateIcon()
        if !launchedAtLogin() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.show() }
        }
    }
    private func launchedAtLogin() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication,
              let prop = event.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return prop.enumCodeValue == keyAELaunchedAsLogInItem
    }
    func popoverWillShow(_ notification: Notification) {
        model.isPopoverShown = true
        model.refreshSystemState()
    }
    func popoverDidClose(_ notification: Notification) {
        model.isPopoverShown = false
        model.clearTransientError()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowsTermination || (!model.connected && !model.anySessionActive) { return .terminateNow }
        model.quit(); return .terminateLater
    }
    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu()
            return
        }
        if popover.isShown { popover.performClose(nil) } else { show() }
    }
    private func showQuickMenu() {
        guard let button = status?.button else { return }
        popover.performClose(nil)
        model.refreshSystemState()
        let menu = NSMenu()
        menu.autoenablesItems = false

        let closedItem = NSMenuItem(title: model.text("合盖不休眠"), action: #selector(quickToggleClosedLid), keyEquivalent: "")
        closedItem.target = self
        closedItem.state = model.enabled ? .on : .off
        closedItem.isEnabled = model.closedLidAction == .toggle
            ? model.canToggle
            : (model.closedLidAction != .checking && model.closedLidAction != .unsupportedMac)
        menu.addItem(closedItem)

        let openItem = NSMenuItem(title: model.text("开盖不休眠"), action: #selector(quickToggleOpenLid), keyEquivalent: "")
        openItem.target = self
        openItem.state = model.openAwakeEnabled ? .on : .off
        openItem.isEnabled = model.canToggleOpenAwake
        menu.addItem(openItem)

        let displayItem = NSMenuItem(title: model.text("屏幕常亮"), action: #selector(quickToggleDisplayAwake), keyEquivalent: "")
        displayItem.target = self
        displayItem.state = model.displayAwakeEnabled ? .on : .off
        displayItem.isEnabled = model.canToggleDisplayAwake
        menu.addItem(displayItem)

        menu.addItem(.separator())

        let optionsItem = NSMenuItem(title: model.text("选项…"), action: #selector(quickOpenOptions), keyEquivalent: ",")
        optionsItem.target = self
        menu.addItem(optionsItem)

        let quitItem = NSMenuItem(title: model.text("退出盖盖"), action: #selector(quickQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        status.menu = menu
        button.performClick(nil)
        status.menu = nil
    }
    @objc private func quickToggleClosedLid() {
        if model.closedLidAction == .toggle { model.toggle() }
        else { model.options = false; show() }
    }
    @objc private func quickToggleOpenLid() { model.setOpenAwake(!model.openAwakeEnabled) }
    @objc private func quickToggleDisplayAwake() { model.setDisplayAwake(!model.displayAwakeEnabled, duration: model.displayDuration) }
    @objc private func quickOpenOptions() { model.options = true; show() }
    @objc private func quickQuit() { NSApp.terminate(nil) }
    private func show() {
        if model.store.confirmation.activateIfPresented() || compatibilitySetup.activateIfPresented() { return }
        guard let button = status?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    private func updateIcon() {
        popover.appearance = model.appearance.nsAppearance
        guard let button = status?.button else { return }
        let state = model.menuState
        let displayAwake = model.displayAwakeEnabled
        let warning = model.state.error ? model.state.message
            : model.state.openAwakeError ? model.state.openAwakeMessage : nil
        let label = warning.map { "\(model.menuLabel) · \(model.text($0))" } ?? model.menuLabel
        let image = state == .off && !displayAwake && warning != nil
            ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: label)
            : GuardianMenuSymbol.image(for: state, displayAwake: displayAwake, accessibilityDescription: label)
        image?.accessibilityDescription = label
        button.setAccessibilityLabel(label)
        button.image = image
        button.title = ""
        button.toolTip = label
    }
}
