import AppKit
import LidOnceCore
import LidOnceSystem

signal(SIGPIPE, SIG_IGN)
if Bundle.main.object(forInfoDictionaryKey: "LidLidDistribution") as? String == "app-store",
   CommandLine.arguments.contains("--agent") {
    fputs("The App Store edition starts sessions through its licensed interface.\n", stderr)
    exit(78)
}
if CommandLine.arguments.contains("--agent") || CommandLine.arguments.contains("--sandbox-check") || CommandLine.arguments.contains("--compatibility-status") {
    // Developer integration entry point. The power owner is the exact same
    // inherited-sandbox executable launched by the UI, never an unsandboxed copy.
    let child = AgentProcess.make()
    if CommandLine.arguments.contains("--sandbox-check") { child.arguments = ["--sandbox-check"] }
    if CommandLine.arguments.contains("--compatibility-status") { child.arguments = ["--compatibility-status"] }
    child.standardInput = FileHandle.standardInput
    child.standardOutput = FileHandle.standardOutput
    child.standardError = FileHandle.standardError
    do {
        try child.run()
        child.waitUntilExit()
        exit(child.terminationStatus)
    } catch {
        fputs(error.localizedDescription + "\n", stderr); exit(1)
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
