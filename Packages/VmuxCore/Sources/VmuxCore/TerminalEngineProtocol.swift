import Foundation
import AppKit

/// Protocol abstracting the terminal engine (Ghostty) for use by non-terminal subsystems.
///
/// Files that need background color, opacity, config reload, or logging from the terminal
/// engine should depend on this protocol rather than the concrete `GhosttyApp` class.
@MainActor
public protocol TerminalEngineProtocol: AnyObject {
    /// The current default terminal background color.
    var defaultBackgroundColor: NSColor { get }

    /// The current default terminal background opacity (0.0 ... 1.0).
    var defaultBackgroundOpacity: Double { get }

    /// Whether background debug logging is enabled.
    var backgroundLogEnabled: Bool { get }

    /// Reload the terminal engine configuration.
    /// - Parameters:
    ///   - soft: If `true`, re-apply the current config without re-reading files.
    ///   - source: A label identifying the caller for debug logging.
    func reloadConfiguration(soft: Bool, source: String)

    /// Open the Ghostty configuration file in TextEdit.
    func openConfigurationInTextEdit()

    /// Synchronize the terminal theme with the current system appearance.
    func synchronizeThemeWithAppearance(_ appearance: NSAppearance?, source: String)

    /// Whether focus-follows-mouse mode is enabled in the terminal config.
    func focusFollowsMouseEnabled() -> Bool

    /// Whether AppleScript automation is enabled in the terminal config.
    func appleScriptAutomationEnabled() -> Bool

    /// Log a background-debug message (only writes when `backgroundLogEnabled` is true).
    func logBackground(_ message: String)
}

/// Default parameter values for protocol methods.
public extension TerminalEngineProtocol {
    func reloadConfiguration(source: String) {
        reloadConfiguration(soft: false, source: source)
    }
}
