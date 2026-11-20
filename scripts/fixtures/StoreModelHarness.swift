import AppKit
import SwiftUI
import Combine
import LidOnceCore

// Compile the real AppModel against a controllable entitlement source and a
// pipe-only worker. Neither StoreKit purchases nor system sleep are exercised.
final class StoreAccessManager: ObservableObject {
    let confirmation = StoreConfirmationPresenter()
    @Published var access: StoreAccess = .loading
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    let isStoreEdition = true
    var allowsStartingClosedLidSession: Bool { permits(Command("arm")) }
    func permits(_ command: Command) -> Bool {
        access.permits(command, inStoreEdition: true, at: now)
    }
    func start() {}
}

struct PanelView: View {
    let model: AppModel
    var body: some View { EmptyView() }
}

enum AgentProcess {
    static func make() -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", CommandLine.arguments[1], CommandLine.arguments[2],
                             CommandLine.arguments[3], CommandLine.arguments[4]]
        return process
    }
}

@main
struct StoreModelHarness {
    static func pump(_ duration: TimeInterval = 0.2) {
        let end = Date().addingTimeInterval(duration)
        while Date() < end { RunLoop.current.run(until: min(end, Date().addingTimeInterval(0.01))) }
    }
    static func wait(_ message: String, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline { pump(0.01) }
        precondition(condition(), message)
    }
    static func commands() -> [String] {
        let text = (try? String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)) ?? ""
        return text.split(separator: "\n").compactMap { line in
            (try? JSONDecoder().decode(Command.self, from: Data(line.utf8)))?.action
        }
    }
    static func main() throws {
        signal(SIGPIPE, SIG_IGN)
        var snapshot = Snapshot(); snapshot.compatibilityReady = true
        try JSONEncoder().encode(snapshot).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        try Data().write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
        let phase = Phase(rawValue: CommandLine.arguments[4])!
        let model = AppModel(); model.conflict = false
        let menuCases: [(Phase, Bool, GuardianMenuState)] = [
            (.off, false, .off), (.armed, false, .on), (.off, true, .openLid), (.armed, true, .both)
        ]
        for (phase, openLid, expected) in menuCases {
            model.state.phase = phase
            model.state.openAwakeRequested = openLid
            precondition(model.menuState == expected, "menu icon must represent both lid modes")
            model.state.displayAwake = DisplayAwakeStatus(active: true, requested: true, deadline: 1800, error: nil)
            precondition(model.menuState == expected, "display keep-awake must not mask either lid mode")
            precondition(model.menuLabel.contains(model.text("屏幕常亮")))
            model.state.displayAwake = nil
        }
        model.state = Snapshot()
        model.launchAgent()
        wait("fixture must connect") { model.connected }

        // Even an unresolved App Store lookup cannot block the free mode.
        precondition(model.canToggleOpenAwake)
        model.setOpenAwake(true)
        wait("free open-lid mode must start while access is loading") { model.openAwakeEnabled }
        model.toggle(); pump()
        precondition(!commands().contains("arm"), "new closed-lid sessions require access")

        let expiry = model.store.now.addingTimeInterval(1)
        model.store.access = .trial(until: expiry)
        pump()
        precondition(model.canToggle)
        model.toggle()
        wait("trial must permit the first closed-lid session") { model.state.phase == phase }
        precondition(model.menuState == .both)
        let before = commands()
        precondition(!before.contains("stop") && !before.contains("open-awake-off"))

        // Exercise the actual Combine callback in AppModel at the deadline.
        let previousHeartbeats = commands().filter { $0 == "ping" }.count
        model.store.now = expiry
        model.store.access = .expired
        pump()
        wait("the actual heartbeat timer must continue after expiry") {
            commands().filter { $0 == "ping" }.count > previousHeartbeats
        }
        precondition(model.state.phase == phase && model.openAwakeEnabled)
        precondition(!commands().contains("stop") && !commands().contains("open-awake-off"),
                     "expiry must not emit sleep-restoration or open-lid shutdown commands")

        // Exercise both ways the accepted session naturally finishes.
        if phase == .closed { model.send(Command("test-reopened")) }
        else { model.toggle() }
        wait("manual stop or lid reopening must finish normally") { model.state.phase == .off }
        precondition(model.menuState == .openLid)
        precondition(!model.canToggle)
        model.toggle()
        model.send(Command("arm"))
        pump()
        precondition(commands().filter { $0 == "arm" }.count == 1)

        model.setOpenAwake(false)
        wait("free mode can be stopped after trial expiry") { !model.openAwakeEnabled }
        model.setOpenAwake(true)
        wait("free mode can restart after trial expiry") { model.openAwakeEnabled }
        model.setOpenAwake(false)
        wait("cleanup must complete") { !model.openAwakeEnabled }
        model.quit()
        wait("worker must exit") { !model.connected }
        print("Store controller \(phase.rawValue): free open-lid mode, uninterrupted expiry, heartbeat, normal finish and blocked rearm passed; no power APIs used")
    }
}
