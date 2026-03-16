import CoreGraphics
import Foundation
import Bonsplit
import VmuxCore

public enum SessionSnapshotSchema {
    public static let currentVersion = 1
}

public enum SessionPersistencePolicy {
    public static let defaultSidebarWidth: Double = 210
    public static let minimumSidebarWidth: Double = 200
    public static let maximumSidebarWidth: Double = 600
    public static let minimumWindowWidth: Double = 300
    public static let minimumWindowHeight: Double = 200
    public static let autosaveInterval: TimeInterval = 8.0
    public static let maxWindowsPerSnapshot: Int = 12
    public static let maxWorkspacesPerWindow: Int = 128
    public static let maxPanelsPerWorkspace: Int = 512
    public static let maxScrollbackLinesPerTerminal: Int = 4000
    public static let maxScrollbackCharactersPerTerminal: Int = 400_000

    public static func sanitizedSidebarWidth(_ candidate: Double?) -> Double {
        let fallback = defaultSidebarWidth
        guard let candidate, candidate.isFinite else { return fallback }
        return min(max(candidate, minimumSidebarWidth), maximumSidebarWidth)
    }

    public static func truncatedScrollback(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        if text.count <= maxScrollbackCharactersPerTerminal {
            return text
        }
        let initialStart = text.index(text.endIndex, offsetBy: -maxScrollbackCharactersPerTerminal)
        let safeStart = ansiSafeTruncationStart(in: text, initialStart: initialStart)
        return String(text[safeStart...])
    }

    /// If truncation starts in the middle of an ANSI CSI escape sequence, advance
    /// to the first printable character after that sequence to avoid replaying
    /// malformed control bytes.
    private static func ansiSafeTruncationStart(in text: String, initialStart: String.Index) -> String.Index {
        guard initialStart > text.startIndex else { return initialStart }
        let escape = "\u{001B}"

        guard let lastEscape = text[..<initialStart].lastIndex(of: Character(escape)) else {
            return initialStart
        }
        let csiMarker = text.index(after: lastEscape)
        guard csiMarker < text.endIndex, text[csiMarker] == "[" else {
            return initialStart
        }

        // If a final CSI byte exists before the truncation boundary, we are not
        // inside a partial sequence.
        if csiFinalByteIndex(in: text, from: csiMarker, upperBound: initialStart) != nil {
            return initialStart
        }

        // We are inside a CSI sequence. Skip to the first character after the
        // sequence terminator if it exists.
        guard let final = csiFinalByteIndex(in: text, from: csiMarker, upperBound: text.endIndex) else {
            return initialStart
        }
        let next = text.index(after: final)
        return next < text.endIndex ? next : text.endIndex
    }

    private static func csiFinalByteIndex(
        in text: String,
        from csiMarker: String.Index,
        upperBound: String.Index
    ) -> String.Index? {
        var index = text.index(after: csiMarker)
        while index < upperBound {
            guard let scalar = text[index].unicodeScalars.first?.value else {
                index = text.index(after: index)
                continue
            }
            if scalar >= 0x40, scalar <= 0x7E {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }
}

public enum SessionRestorePolicy {
    public static func isRunningUnderAutomatedTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["VMUX_UI_TEST_MODE"] == "1" {
            return true
        }
        if environment.keys.contains(where: { $0.hasPrefix("VMUX_UI_TEST_") }) {
            return true
        }
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if environment["XCTestBundlePath"] != nil {
            return true
        }
        if environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        if environment["XCInjectBundle"] != nil {
            return true
        }
        if environment["XCInjectBundleInto"] != nil {
            return true
        }
        if environment["DYLD_INSERT_LIBRARIES"]?.contains("libXCTest") == true {
            return true
        }
        return false
    }

    public static func shouldAttemptRestore(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["VMUX_DISABLE_SESSION_RESTORE"] == "1" {
            return false
        }
        if isRunningUnderAutomatedTests(environment: environment) {
            return false
        }

        let extraArgs = arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-psn_") }

        // Any explicit launch argument is treated as an explicit open intent.
        return extraArgs.isEmpty
    }
}

public struct SessionRectSnapshot: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct SessionDisplaySnapshot: Codable, Sendable {
    public var displayID: UInt32?
    public var frame: SessionRectSnapshot?
    public var visibleFrame: SessionRectSnapshot?

    public init(displayID: UInt32? = nil, frame: SessionRectSnapshot? = nil, visibleFrame: SessionRectSnapshot? = nil) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum SessionSidebarSelection: String, Codable, Sendable, Equatable {
    case tabs
    case notifications

    public init(selection: SidebarSelection) {
        switch selection {
        case .tabs:
            self = .tabs
        case .notifications:
            self = .notifications
        }
    }

    public var sidebarSelection: SidebarSelection {
        switch self {
        case .tabs:
            return .tabs
        case .notifications:
            return .notifications
        }
    }
}

public struct SessionSidebarSnapshot: Codable, Sendable {
    public var isVisible: Bool
    public var selection: SessionSidebarSelection
    public var width: Double?

    public init(isVisible: Bool, selection: SessionSidebarSelection, width: Double? = nil) {
        self.isVisible = isVisible
        self.selection = selection
        self.width = width
    }
}

public struct SessionStatusEntrySnapshot: Codable, Sendable {
    public var key: String
    public var value: String
    public var icon: String?
    public var color: String?
    public var timestamp: TimeInterval

    public init(key: String, value: String, icon: String? = nil, color: String? = nil, timestamp: TimeInterval) {
        self.key = key
        self.value = value
        self.icon = icon
        self.color = color
        self.timestamp = timestamp
    }
}

public struct SessionLogEntrySnapshot: Codable, Sendable {
    public var message: String
    public var level: String
    public var source: String?
    public var timestamp: TimeInterval

    public init(message: String, level: String, source: String? = nil, timestamp: TimeInterval) {
        self.message = message
        self.level = level
        self.source = source
        self.timestamp = timestamp
    }
}

public struct SessionProgressSnapshot: Codable, Sendable {
    public var value: Double
    public var label: String?

    public init(value: Double, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

public struct SessionGitBranchSnapshot: Codable, Sendable {
    public var branch: String
    public var isDirty: Bool

    public init(branch: String, isDirty: Bool) {
        self.branch = branch
        self.isDirty = isDirty
    }
}

public struct SessionTerminalPanelSnapshot: Codable, Sendable {
    public var workingDirectory: String?
    public var scrollback: String?

    public init(workingDirectory: String? = nil, scrollback: String? = nil) {
        self.workingDirectory = workingDirectory
        self.scrollback = scrollback
    }
}

public struct SessionBrowserPanelSnapshot: Codable, Sendable {
    public var urlString: String?
    public var shouldRenderWebView: Bool
    public var pageZoom: Double
    public var developerToolsVisible: Bool
    public var backHistoryURLStrings: [String]?
    public var forwardHistoryURLStrings: [String]?

    public init(
        urlString: String? = nil,
        shouldRenderWebView: Bool,
        pageZoom: Double,
        developerToolsVisible: Bool,
        backHistoryURLStrings: [String]? = nil,
        forwardHistoryURLStrings: [String]? = nil
    ) {
        self.urlString = urlString
        self.shouldRenderWebView = shouldRenderWebView
        self.pageZoom = pageZoom
        self.developerToolsVisible = developerToolsVisible
        self.backHistoryURLStrings = backHistoryURLStrings
        self.forwardHistoryURLStrings = forwardHistoryURLStrings
    }
}

public struct SessionMarkdownPanelSnapshot: Codable, Sendable {
    public var filePath: String

    public init(filePath: String) {
        self.filePath = filePath
    }
}

public struct SessionPanelSnapshot: Codable, Sendable {
    public var id: UUID
    public var type: PanelType
    public var title: String?
    public var customTitle: String?
    public var directory: String?
    public var isPinned: Bool
    public var isManuallyUnread: Bool
    public var gitBranch: SessionGitBranchSnapshot?
    public var listeningPorts: [Int]
    public var ttyName: String?
    public var terminal: SessionTerminalPanelSnapshot?
    public var browser: SessionBrowserPanelSnapshot?
    public var markdown: SessionMarkdownPanelSnapshot?

    public init(
        id: UUID,
        type: PanelType,
        title: String? = nil,
        customTitle: String? = nil,
        directory: String? = nil,
        isPinned: Bool,
        isManuallyUnread: Bool,
        gitBranch: SessionGitBranchSnapshot? = nil,
        listeningPorts: [Int],
        ttyName: String? = nil,
        terminal: SessionTerminalPanelSnapshot? = nil,
        browser: SessionBrowserPanelSnapshot? = nil,
        markdown: SessionMarkdownPanelSnapshot? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.customTitle = customTitle
        self.directory = directory
        self.isPinned = isPinned
        self.isManuallyUnread = isManuallyUnread
        self.gitBranch = gitBranch
        self.listeningPorts = listeningPorts
        self.ttyName = ttyName
        self.terminal = terminal
        self.browser = browser
        self.markdown = markdown
    }
}

public enum SessionSplitOrientation: String, Codable, Sendable {
    case horizontal
    case vertical

    public init(_ orientation: SplitOrientation) {
        switch orientation {
        case .horizontal:
            self = .horizontal
        case .vertical:
            self = .vertical
        }
    }

    public var splitOrientation: SplitOrientation {
        switch self {
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        }
    }
}

public struct SessionPaneLayoutSnapshot: Codable, Sendable {
    public var panelIds: [UUID]
    public var selectedPanelId: UUID?

    public init(panelIds: [UUID], selectedPanelId: UUID? = nil) {
        self.panelIds = panelIds
        self.selectedPanelId = selectedPanelId
    }
}

public struct SessionSplitLayoutSnapshot: Codable, Sendable {
    public var orientation: SessionSplitOrientation
    public var dividerPosition: Double
    public var first: SessionWorkspaceLayoutSnapshot
    public var second: SessionWorkspaceLayoutSnapshot

    public init(orientation: SessionSplitOrientation, dividerPosition: Double, first: SessionWorkspaceLayoutSnapshot, second: SessionWorkspaceLayoutSnapshot) {
        self.orientation = orientation
        self.dividerPosition = dividerPosition
        self.first = first
        self.second = second
    }
}

public indirect enum SessionWorkspaceLayoutSnapshot: Codable, Sendable {
    case pane(SessionPaneLayoutSnapshot)
    case split(SessionSplitLayoutSnapshot)

    private enum CodingKeys: String, CodingKey {
        case type
        case pane
        case split
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pane":
            self = .pane(try container.decode(SessionPaneLayoutSnapshot.self, forKey: .pane))
        case "split":
            self = .split(try container.decode(SessionSplitLayoutSnapshot.self, forKey: .split))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported layout node type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pane(let pane):
            try container.encode("pane", forKey: .type)
            try container.encode(pane, forKey: .pane)
        case .split(let split):
            try container.encode("split", forKey: .type)
            try container.encode(split, forKey: .split)
        }
    }
}

public struct SessionWorkspaceSnapshot: Codable, Sendable {
    public var workspaceId: UUID?
    public var processTitle: String
    public var customTitle: String?
    public var customColor: String?
    public var isPinned: Bool
    public var currentDirectory: String
    public var focusedPanelId: UUID?
    public var layout: SessionWorkspaceLayoutSnapshot
    public var panels: [SessionPanelSnapshot]
    public var statusEntries: [SessionStatusEntrySnapshot]
    public var logEntries: [SessionLogEntrySnapshot]
    public var progress: SessionProgressSnapshot?
    public var gitBranch: SessionGitBranchSnapshot?

    public init(
        workspaceId: UUID? = nil,
        processTitle: String,
        customTitle: String? = nil,
        customColor: String? = nil,
        isPinned: Bool,
        currentDirectory: String,
        focusedPanelId: UUID? = nil,
        layout: SessionWorkspaceLayoutSnapshot,
        panels: [SessionPanelSnapshot],
        statusEntries: [SessionStatusEntrySnapshot],
        logEntries: [SessionLogEntrySnapshot],
        progress: SessionProgressSnapshot? = nil,
        gitBranch: SessionGitBranchSnapshot? = nil
    ) {
        self.workspaceId = workspaceId
        self.processTitle = processTitle
        self.customTitle = customTitle
        self.customColor = customColor
        self.isPinned = isPinned
        self.currentDirectory = currentDirectory
        self.focusedPanelId = focusedPanelId
        self.layout = layout
        self.panels = panels
        self.statusEntries = statusEntries
        self.logEntries = logEntries
        self.progress = progress
        self.gitBranch = gitBranch
    }
}

public struct SessionTabManagerSnapshot: Codable, Sendable {
    public var selectedWorkspaceIndex: Int?
    public var workspaces: [SessionWorkspaceSnapshot]
    public var folderTree: [SidebarItem]?

    public init(selectedWorkspaceIndex: Int? = nil, workspaces: [SessionWorkspaceSnapshot], folderTree: [SidebarItem]? = nil) {
        self.selectedWorkspaceIndex = selectedWorkspaceIndex
        self.workspaces = workspaces
        self.folderTree = folderTree
    }
}

public struct SessionWindowSnapshot: Codable, Sendable {
    public var frame: SessionRectSnapshot?
    public var display: SessionDisplaySnapshot?
    public var tabManager: SessionTabManagerSnapshot
    public var sidebar: SessionSidebarSnapshot

    public init(frame: SessionRectSnapshot? = nil, display: SessionDisplaySnapshot? = nil, tabManager: SessionTabManagerSnapshot, sidebar: SessionSidebarSnapshot) {
        self.frame = frame
        self.display = display
        self.tabManager = tabManager
        self.sidebar = sidebar
    }
}

public struct AppSessionSnapshot: Codable, Sendable {
    public var version: Int
    public var createdAt: TimeInterval
    public var windows: [SessionWindowSnapshot]

    public init(version: Int, createdAt: TimeInterval, windows: [SessionWindowSnapshot]) {
        self.version = version
        self.createdAt = createdAt
        self.windows = windows
    }
}

public enum SessionPersistenceStore {
    public static func load(fileURL: URL? = nil) -> AppSessionSnapshot? {
        guard let fileURL = fileURL ?? defaultSnapshotFileURL() else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        guard let snapshot = try? decoder.decode(AppSessionSnapshot.self, from: data) else { return nil }
        guard snapshot.version == SessionSnapshotSchema.currentVersion else { return nil }
        guard !snapshot.windows.isEmpty else { return nil }
        return snapshot
    }

    @discardableResult
    public static func save(_ snapshot: AppSessionSnapshot, fileURL: URL? = nil) -> Bool {
        guard let fileURL = fileURL ?? defaultSnapshotFileURL() else { return false }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public static func removeSnapshot(fileURL: URL? = nil) {
        guard let fileURL = fileURL ?? defaultSnapshotFileURL() else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    public static func defaultSnapshotFileURL(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        appSupportDirectory: URL? = nil
    ) -> URL? {
        let resolvedAppSupport: URL
        if let appSupportDirectory {
            resolvedAppSupport = appSupportDirectory
        } else if let discovered = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            resolvedAppSupport = discovered
        } else {
            return nil
        }
        let bundleId = (bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? bundleIdentifier!
            : "com.vmuxterm.app"
        let safeBundleId = bundleId.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
        return resolvedAppSupport
            .appendingPathComponent("vmux", isDirectory: true)
            .appendingPathComponent("session-\(safeBundleId).json", isDirectory: false)
    }
}

public enum SessionScrollbackReplayStore {
    public static let environmentKey = "VMUX_RESTORE_SCROLLBACK_FILE"
    private static let directoryName = "vmux-session-scrollback"
    private static let ansiEscape = "\u{001B}"
    private static let ansiReset = "\u{001B}[0m"

    public static func replayEnvironment(
        for scrollback: String?,
        tempDirectory: URL = FileManager.default.temporaryDirectory
    ) -> [String: String] {
        guard let replayText = normalizedScrollback(scrollback) else { return [:] }
        guard let replayFileURL = writeReplayFile(
            contents: replayText,
            tempDirectory: tempDirectory
        ) else {
            return [:]
        }
        return [environmentKey: replayFileURL.path]
    }

    private static func normalizedScrollback(_ scrollback: String?) -> String? {
        guard let scrollback else { return nil }
        guard scrollback.contains(where: { !$0.isWhitespace }) else { return nil }
        guard let truncated = SessionPersistencePolicy.truncatedScrollback(scrollback) else { return nil }
        return ansiSafeReplayText(truncated)
    }

    /// Preserve ANSI color state safely across replay boundaries.
    private static func ansiSafeReplayText(_ text: String) -> String {
        guard text.contains(ansiEscape) else { return text }
        var output = text
        if !output.hasPrefix(ansiReset) {
            output = ansiReset + output
        }
        if !output.hasSuffix(ansiReset) {
            output += ansiReset
        }
        return output
    }

    private static func writeReplayFile(contents: String, tempDirectory: URL) -> URL? {
        guard let data = contents.data(using: .utf8) else { return nil }
        let directory = tempDirectory.appendingPathComponent(directoryName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let fileURL = directory
                .appendingPathComponent(UUID().uuidString, isDirectory: false)
                .appendingPathExtension("txt")
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}
