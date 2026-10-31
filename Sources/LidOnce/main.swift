import AppKit
import LidOnceCore

signal(SIGPIPE, SIG_IGN)
if CommandLine.arguments.contains("--agent") {
    do {
        let agent = try SessionAgent()
        try agent.start()
        withExtendedLifetime(agent) { RunLoop.main.run() }
    } catch {
        var state = Snapshot(); state.error = true; state.message = error.localizedDescription
        if let data = try? JSONEncoder().encode(state) { try? FileHandle.standardOutput.write(contentsOf: data + Data([10])) }
        exit(1)
    }
} else if CommandLine.arguments.contains("--check") {
    do {
        let driver = try PowerDriver()
        var result = Snapshot()
        result.lidClosed = driver.bool("AppleClamshellState")
        result.causesSleep = driver.bool("AppleClamshellCausesSleep")
        let battery = batteryReading(); result.battery = battery.percent; result.onBattery = battery.onBattery
        result.thermal = thermalLabel()
        result.message = "只读检查；外接屏 \(try externalDisplayCount())；Clamshell 运行 \(conflictingApp())"
        print(String(data: try JSONEncoder().encode(result), encoding: .utf8)!)
    } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
