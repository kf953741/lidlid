import AppKit
import LidOnceCore
import LidOnceSystem

signal(SIGPIPE, SIG_IGN)
do {
    if CommandLine.arguments.contains("--compatibility-status") {
        let client = CompatibilityClient()
        client.status { result in
            switch result {
            case .success(let status):
                let data = try! JSONSerialization.data(withJSONObject: [
                    "available": true, "active": status.active, "recoveryPending": status.recoveryPending,
                    "sandboxContainer": NSHomeDirectory()
                ], options: [.sortedKeys])
                print(String(decoding: data, as: UTF8.self)); exit(0)
            case .failure(let error):
                fputs(error.localizedDescription + "\n", stderr); exit(1)
            }
        }
        withExtendedLifetime(client) { RunLoop.main.run() }
    }
    if CommandLine.arguments.contains("--sandbox-check") {
        // Read-only packaging check, also usable on desktop CI machines.
        let driver = try PowerDriver()
        let data = try JSONSerialization.data(withJSONObject: [
            "agentPID": getpid(), "sandboxContainer": NSHomeDirectory(),
            "rootDomainOpened": true, "lidSensorPresent": driver.bool("AppleClamshellState") != nil
        ], options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(0)
    }
    let agent = try SessionAgent()
    try agent.start()
    withExtendedLifetime(agent) { RunLoop.main.run() }
} catch {
    var state = Snapshot(); state.error = true; state.message = error.localizedDescription
    if let data = try? JSONEncoder().encode(state) {
        try? FileHandle.standardOutput.write(contentsOf: data + Data([10]))
    }
    exit(1)
}
