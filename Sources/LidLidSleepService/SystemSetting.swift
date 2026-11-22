import Foundation
import IOKit
import LidLidServiceCore
import LidOnceSystem

struct SystemSleepSetting: SleepSetting {
    let root: PowerDriver
    static func parse(_ output: String) throws -> Bool {
        let values = output.split(whereSeparator: \.isNewline).compactMap { line -> Bool? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2, fields[0] == "SleepDisabled" else { return nil }
            if fields[1] == "0" { return false }
            if fields[1] == "1" { return true }
            return nil
        }
        guard values.count == 1 else { throw ServiceFailure("无法读取系统睡眠设置，请稍后重试") }
        return values[0]
    }
    func read() throws -> Bool {
        let saved = try Self.parse(run(["-g"]))
        guard root.bool("SleepDisabled") == saved else {
            throw ServiceFailure("兼容组件未能确认睡眠设置，请稍后重试")
        }
        return saved
    }
    func write(disabled: Bool) throws {
        _ = try run(["-a", "disablesleep", disabled ? "1" : "0"])
        // The persistent preference alone is not proof the kernel applied it.
        // Wait a bounded interval for the actual root-domain property as well.
        let until = ProcessInfo.processInfo.systemUptime + 1
        while root.bool("SleepDisabled") != disabled {
            guard ProcessInfo.processInfo.systemUptime < until else {
                throw ServiceFailure("兼容组件未能确认睡眠设置，请稍后重试")
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    // Fixed executable and arguments only. No shell, sudoers, caller-supplied
    // path, command, environment, or arbitrarily privileged file operations.
    private func run(_ arguments: [String]) throws -> String {
        let task = Process(), pipe = Pipe(), done = DispatchSemaphore(value: 0)
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = arguments
        task.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"]
        task.standardOutput = pipe; task.standardError = FileHandle.nullDevice
        var output = Data()
        let readDone = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in done.signal() }
        try task.run()
        try? pipe.fileHandleForWriting.close()
        DispatchQueue.global(qos: .utility).async {
            output = pipe.fileHandleForReading.readDataToEndOfFile()
            readDone.signal()
        }
        guard done.wait(timeout: .now() + 4) == .success else {
            kill(task.processIdentifier, SIGKILL)
            _ = done.wait(timeout: .now() + 1)
            _ = readDone.wait(timeout: .now() + 1)
            throw ServiceFailure("系统睡眠设置超时，请保持开盖并重试")
        }
        guard readDone.wait(timeout: .now() + 1) == .success else {
            throw ServiceFailure("系统睡眠设置响应异常")
        }
        guard task.terminationStatus == 0 else { throw ServiceFailure("系统拒绝兼容组件的睡眠设置") }
        guard output.count <= 16_384 else { throw ServiceFailure("系统睡眠设置响应异常") }
        return String(decoding: output, as: UTF8.self)
    }
}
