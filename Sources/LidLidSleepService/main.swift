import Darwin
import Foundation
import SystemConfiguration
import OSLog
import LidLidServiceCore
import LidLidServiceProtocol
import LidOnceSystem

let logger = Logger(subsystem: CompatibilityService.daemonID, category: "sleep")
let epoch = ContinuousClock.now
func now() -> TimeInterval {
    let components = epoch.duration(to: .now).components
    return Double(components.seconds) + Double(components.attoseconds) / 1e18
}
func consoleUser(_ uid: uid_t) -> Bool {
    var current: uid_t = 0
    _ = SCDynamicStoreCopyConsoleUser(nil, &current, nil)
    return uid != 0 && current == uid
}

final class ServiceEndpoint: NSObject, LidLidSleepServiceProtocol {
    let id = UUID()
    let uid: uid_t
    let controller: SleepLease
    let power: PowerDriver
    init(uid: uid_t, controller: SleepLease, power: PowerDriver) {
        self.uid = uid; self.controller = controller; self.power = power
    }
    func status(reply: @escaping (Int, Bool, Bool) -> Void) {
        DispatchQueue.main.async { reply(CompatibilityService.version, self.controller.active, self.controller.recoveryPending) }
    }
    func beginSession(minutes: Int, reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard consoleUser(self.uid), self.safe(), self.power.bool("AppleClamshellState") == false else {
                throw ServiceFailure("请保持开盖，确认电量、温度和显示器状态后重试")
            }
            try self.controller.begin(owner: self.id, minutes: minutes, now: now(), lidClosed: false)
            logger.notice("Session began; original system sleep setting journaled")
        }
    }
    func renewSession(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard consoleUser(self.uid), self.safe() else {
                try self.controller.end(owner: self.id)
                throw ServiceFailure("电量、温度或用户状态改变，本次已结束")
            }
            try self.controller.renew(owner: self.id, now: now())
        }
    }
    func endSession(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) { try self.controller.end(owner: self.id) }
    }
    func prepareForRemoval(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) { try self.controller.pauseAndRestore() }
    }
    func disconnected() {
        DispatchQueue.main.async {
            do { try self.controller.end(owner: self.id) }
            catch { logger.error("Disconnect recovery pending: \(error.localizedDescription, privacy: .public)") }
        }
    }
    private func perform(_ reply: @escaping (Bool, String?) -> Void, operation: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            do { try operation(); reply(true, nil) }
            catch { logger.error("Service operation: \(error.localizedDescription, privacy: .public)"); reply(false, error.localizedDescription) }
        }
    }
    func safe() -> Bool {
        let battery = batteryReading()
        return battery.percent != nil && (!battery.onBattery || battery.percent! > 10)
            && ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
            && (try? externalDisplayCount()) == 0
    }
}

final class Listener: NSObject, NSXPCListenerDelegate {
    let controller: SleepLease
    let power: PowerDriver
    init(controller: SleepLease, power: PowerDriver) { self.controller = controller; self.power = power }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard consoleUser(connection.effectiveUserIdentifier) else { return false }
        let service = ServiceEndpoint(uid: connection.effectiveUserIdentifier, controller: controller, power: power)
        connection.exportedInterface = NSXPCInterface(with: LidLidSleepServiceProtocol.self)
        connection.exportedObject = service
        connection.invalidationHandler = { service.disconnected() }
        connection.interruptionHandler = { service.disconnected() }
        connection.resume()
        return true
    }
}

if CommandLine.arguments.contains("--self-test") {
    // Pure parser check: never registers a service or changes power settings.
    let parsed = try! SystemSleepSetting.parse("System-wide power settings:\n SleepDisabled 0\n")
    precondition(parsed == false)
    print("LidLid sleep service parser passed; no settings changed")
    exit(0)
}
guard geteuid() == 0 else { fputs("Start this service through the compatibility app and macOS approval.\n", stderr); exit(1) }
do {
    let power = try PowerDriver()
    let controller = SleepLease(power: SystemSleepSetting(root: power), journal: try RootJournal())
    // Recover before exposing XPC. A failure stays alive and retries instead of
    // forgetting a persistent override after a crash, SIGKILL, or power loss.
    do { try controller.recover() }
    catch { logger.fault("Startup restoration pending: \(error.localizedDescription, privacy: .public)") }
    let delegate = Listener(controller: controller, power: power)
    let listener = NSXPCListener(machServiceName: CompatibilityService.name)
    listener.setConnectionCodeSigningRequirement(CompatibilityService.clientRequirement)
    listener.delegate = delegate
    listener.resume()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: 1)
    timer.setEventHandler {
        guard controller.active || controller.recoveryPending else { return }
        let battery = batteryReading()
        var current: uid_t = 0
        _ = SCDynamicStoreCopyConsoleUser(nil, &current, nil)
        let safe = current != 0 && battery.percent != nil && (!battery.onBattery || battery.percent! > 10)
            && ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
        do { try controller.tick(now: now(), lidClosed: power.bool("AppleClamshellState"), safe: safe) }
        catch { logger.error("Restoration retry pending: \(error.localizedDescription, privacy: .public)") }
    }
    timer.resume()
    var signals: [DispatchSourceSignal] = []
    for code in [SIGTERM, SIGINT] {
        signal(code, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: code, queue: .main)
        source.setEventHandler {
            do { try controller.pauseAndRestore(); exit(0) }
            catch { logger.fault("Shutdown recovery retained on disk: \(error.localizedDescription, privacy: .public)"); exit(1) }
        }
        source.resume(); signals.append(source)
    }
    withExtendedLifetime((listener, delegate, timer, signals)) { RunLoop.main.run() }
} catch { logger.fault("Service initialization failed: \(error.localizedDescription, privacy: .public)"); exit(1) }
