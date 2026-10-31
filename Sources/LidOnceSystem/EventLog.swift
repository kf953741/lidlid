import Foundation

public enum EventLog {
    public static func write(_ message: String) {
        let manager = FileManager.default
        let directory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LidOnce", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("events.log")
        // Retain old evidence as a dated file instead of silently overwriting it.
        if let attributes = try? manager.attributesOfItem(atPath: file.path),
           let size = attributes[.size] as? NSNumber, size.intValue > 512_000 {
            try? manager.moveItem(at: file, to: directory.appendingPathComponent("events-\(Int(Date().timeIntervalSince1970)).log"))
        }
        if !manager.fileExists(atPath: file.path) {
            manager.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: file) else { return }
        defer { try? handle.close() }
        let text = "\(ISO8601DateFormatter().string(from: Date())) pid=\(getpid()) \(message)\n"
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }
}
