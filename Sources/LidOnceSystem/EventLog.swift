import Foundation

public enum EventLog {
    public static func write(_ message: String) {
        let manager = FileManager.default
        let directory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LidOnce", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("events.log")
        // Retain recent evidence as dated files while capping total archives.
        if let attributes = try? manager.attributesOfItem(atPath: file.path),
           let size = attributes[.size] as? NSNumber, size.intValue > 512_000 {
            try? manager.moveItem(at: file, to: directory.appendingPathComponent("events-\(Int(Date().timeIntervalSince1970)).log"))
            pruneArchives(in: directory, keeping: 5)
        }
        if !manager.fileExists(atPath: file.path) {
            manager.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: file) else { return }
        defer { try? handle.close() }
        let timestamp = Date().formatted(.iso8601)
        let text = "\(timestamp) pid=\(getpid()) \(message)\n"
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }

    private static func pruneArchives(in directory: URL, keeping limit: Int) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let archives = files
            .filter { $0.lastPathComponent.hasPrefix("events-") && $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in archives.dropFirst(limit) { try? manager.removeItem(at: stale) }
    }
}
