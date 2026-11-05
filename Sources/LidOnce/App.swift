import AppKit
import SwiftUI
import Combine
import ServiceManagement
import LidOnceCore
import LidOnceSystem

final class AppModel: ObservableObject {
    let store = StoreAccessManager()
    private var storeChanges: AnyCancellable?
    @Published var state = Snapshot()
    @Published var connected = false
    @Published var conflict = conflictingApp()
    @Published var options = false
    @Published var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            changed?()
        }
    }
    @Published var maximumMinutes = UserDefaults.standard.integer(forKey: "maximumMinutes") {
        didSet { UserDefaults.standard.set(maximumMinutes, forKey: "maximumMinutes") }
    }
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginMessage: String?
    var changed: (() -> Void)?
    var readyToQuit: (() -> Void)?
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var buffer = Data()
    private var heartbeat: Timer?
    private var quitting = false
    private var requestedArm = false
    private let repairClient = CompatibilityClient()
    private var checkingRepair = false
    private var repairTimer: Timer?

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
    var anySessionActive: Bool { busy || openAwakeEnabled }
    var menuState: GuardianMenuState { openAwakeEnabled ? .openLid : enabled ? .on : .off }
    var canToggleOpenAwake: Bool { connected && !quitting && !(!state.openAwakeRequested && state.openAwakeActive) }
    var menuLabel: String {
        text(openAwakeEnabled ? (enabled ? "盖盖：合盖与开盖不休眠已开启" : "盖盖：开盖不休眠已开启")
             : enabled ? "盖盖：已开启，仅本次合盖不休眠" : "盖盖：已关闭")
    }
    // The one-shot needs armed/closed internally; the person sees a single on state.
    var enabled: Bool { state.phase == .armed || state.phase == .closed || state.phase == .restoring }
    var changing: Bool { state.phase == .starting || state.phase == .restoring }
    var canToggle: Bool { connected && !changing && (enabled || store.allowsStartingClosedLidSession) && (!conflict || enabled) && (enabled || state.compatibilityReady) }
    var text: AppText { AppText(language: language) }
    var brandName: String { text("盖盖") }
    var detail: String {
        if state.phase == .off && !state.error && state.message != Snapshot().message {
            return text(state.message)
        }
        return text("开盖自动关闭，下次恢复正常睡眠。")
    }
    var durationLabel: String { text.duration(maximumMinutes) }
    var title: String {
        switch state.phase {
        case .off: return text("已关闭")
        case .starting: return text("正在开启…")
        case .armed, .closed: return text("已开启")
        case .restoring: return text("正在关闭…")
        }
    }
    func launchAgent() {
        guard process == nil else { return }
        let child = AgentProcess.make(), stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        input = stdin; output = stdout; process = child
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { self?.consume(data) }
        }
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.agentEnded() }
        }
        do {
            try child.run()
            // Only the agent may own the read end; a UI crash must cause EOF.
            try? stdin.fileHandleForReading.close()
            try? stdout.fileHandleForWriting.close()
        } catch {
            process = nil; state.error = true; state.message = "无法启动合盖进程：\(error.localizedDescription)"
        }
        heartbeat = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.send(Command("ping")); self.conflict = conflictingApp()
        }
        // Native menus use an event-tracking run-loop mode. Keep the heartbeat
        // running while a duration or language menu is open.
        RunLoop.main.add(heartbeat!, forMode: .common)
    }
    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
            guard let update = try? JSONDecoder().decode(Snapshot.self, from: line) else { continue }
            state = update; connected = true
            if update.phase == .off { requestedArm = false }
            changed?()
            if quitting && update.phase == .off && !update.openAwakeRequested && !update.openAwakeActive { send(Command("quit")) }
        }
    }
    func send(_ command: Command) {
        guard store.permits(command) else { return }
        guard process?.isRunning == true, let handle = input?.fileHandleForWriting,
              let data = try? JSONEncoder().encode(command) else { return }
        try? handle.write(contentsOf: data + Data([10]))
    }
    func toggle() {
        guard connected, state.phase != .starting, state.phase != .restoring else { return }
        if busy { send(Command("stop")) }
        else if store.allowsStartingClosedLidSession { requestedArm = true; send(Command("arm", minutes: maximumMinutes)) }
    }
    func setOpenAwake(_ enabled: Bool) {
        guard canToggleOpenAwake else { return }
        send(Command(enabled ? "open-awake-on" : "open-awake-off"))
    }
    func quit() {
        quitting = true
        if process?.isRunning == true { send(Command("quit")) }
        else { readyToQuit?() }
    }
    private func agentEnded() {
        output?.fileHandleForReading.readabilityHandler = nil
        heartbeat?.invalidate(); heartbeat = nil
        connected = false; process = nil
        // The worker's XPC disconnect revokes its lease. Confirm recovery via
        // the independently running service before showing Off.
        if anySessionActive || requestedArm {
            state.phase = .restoring; state.error = true
            state.message = "合盖进程意外结束，正在恢复睡眠…"
            repairTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.repair() }
            RunLoop.main.add(repairTimer!, forMode: .common)
            repair()
        } else if quitting { readyToQuit?() }
        else { state.error = true; state.message = "合盖进程已结束，请重新打开盖盖" }
        changed?()
    }
    private func repair() {
        guard !checkingRepair else { return }
        checkingRepair = true
        repairClient.status { [weak self] result in
            guard let self else { return }
            self.checkingRepair = false
            let confirmed: Bool
            if case .success(let status) = result { confirmed = !status.active && !status.recoveryPending }
            else { confirmed = (try? PowerDriver().bool("SleepDisabled")) == false }
            if confirmed {
                EventLog.write("parent recovery: original sleep setting confirmed after agent exit")
                self.repairTimer?.invalidate(); self.repairTimer = nil
                self.state.phase = .off; self.state.error = true
                self.state.openAwakeRequested = false; self.state.openAwakeActive = false
                self.state.message = "意外退出后已恢复睡眠，请重新打开盖盖"
                self.requestedArm = false
                if self.quitting { self.readyToQuit?() }
            } else { self.state.message = "兼容组件正在恢复睡眠，请保持开盖" }
            self.changed?()
        }
    }
    func openCompatibility() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.kf.lidonce.compatibility") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            // User installs the free component independently; the sandboxed
            // Store app never downloads, installs, or elevates another program.
            NSWorkspace.shared.open(URL(string: language.resolved() == .simplifiedChinese
                ? "https://lidlid.vercel.app/support/#compatibility"
                : "https://lidlid.vercel.app/en/support/#compatibility")!)
        }
    }
    func exitReference() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.rathonyi.clamshell") { app.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.conflict = conflictingApp() }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginMessage = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置 → 登录项中允许盖盖" : nil
        } catch { loginEnabled = SMAppService.mainApp.status == .enabled; loginMessage = error.localizedDescription }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var status: NSStatusItem!
    private let popover = NSPopover()
    private var allowsTermination = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != getpid() }) {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = status.button {
            button.target = self; button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(model.brandName)
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PanelView(model: model))
        model.changed = { [weak self] in self?.updateIcon() }
        model.readyToQuit = { [weak self] in
            self?.allowsTermination = true
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        model.launchAgent(); updateIcon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowsTermination || (!model.connected && !model.anySessionActive) { return .terminateNow }
        model.quit(); return .terminateLater
    }
    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            if !model.store.allowsStartingClosedLidSession && !model.enabled { show() }
            else { model.toggle() }
            return
        }
        if popover.isShown { popover.performClose(nil) } else { show() }
    }
    private func show() {
        guard let button = status?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    private func updateIcon() {
        status?.button?.setAccessibilityLabel(model.brandName)
        status?.button?.image = (model.state.error || model.state.openAwakeError)
            ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: model.text(model.state.error ? model.state.message : model.state.openAwakeMessage))
            : GuardianMenuSymbol.image(for: model.menuState)
        if !model.state.error && !model.state.openAwakeError {
            status?.button?.image?.accessibilityDescription = model.menuLabel
        }
        status?.button?.title = ""
        status?.button?.toolTip = model.menuLabel
    }
}
