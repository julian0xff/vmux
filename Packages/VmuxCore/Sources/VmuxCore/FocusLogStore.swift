import Foundation

public final class FocusLogStore {
    public static let shared = FocusLogStore()

    private let queue = DispatchQueue(label: "vmux.focus.log")
    private var entries: [String] = []
    private let maxEntries = 400
    private let logURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logURL = logsDir.appendingPathComponent("Logs/vmux-focus.log")
        ensureLogFile()
    }

    public func append(_ message: String) {
        #if DEBUG
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        queue.async { [weak self] in
            guard let self else { return }
            entries.append(line)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            appendToFile(line: line)
        }
        #endif
    }

    public func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    public func logPath() -> String {
        logURL.path
    }

    private func ensureLogFile() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? Data().write(to: logURL)
        }
    }

    private func appendToFile(line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}
