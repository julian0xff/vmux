import Foundation
import AppKit

public final class UpdateLogStore {
    public static let shared = UpdateLogStore()

    private let queue = DispatchQueue(label: "vmux.update.log")
    private var entries: [String] = []
    private let maxEntries = 200
    private let logURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logURL = logsDir.appendingPathComponent("Logs/vmux-update.log")
        ensureLogFile()
    }

    public func append(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let bundle = Bundle.main.bundleIdentifier ?? "<no.bundle.id>"
        let pid = ProcessInfo.processInfo.processIdentifier
        let line = "[\(timestamp)] [\(bundle):\(pid)] \(message)"
        queue.async { [weak self] in
            guard let self else { return }
            entries.append(line)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            appendToFile(line: line)
        }
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
