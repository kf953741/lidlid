import Foundation

enum AgentProcess {
    static func make() -> Process {
        let child = Process()
        child.executableURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/LidLidAgent", isDirectory: false)
        return child
    }
}
