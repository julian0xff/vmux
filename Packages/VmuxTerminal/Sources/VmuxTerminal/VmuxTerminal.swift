@_exported import VmuxCore

/// Shared accessor for the terminal engine singleton.
///
/// Subsystems that need terminal background color, opacity, config reload, or logging
/// should use `TerminalEngine.shared` through the `TerminalEngineProtocol` interface
/// rather than reaching for the concrete `GhosttyApp` class.
public enum TerminalEngine {
    /// The active terminal engine instance.
    ///
    /// Set by the app delegate at launch before any consumers access it.
    @MainActor
    public private(set) static var shared: (any TerminalEngineProtocol)?

    /// Register the terminal engine singleton. Call once at app startup.
    @MainActor
    public static func register(_ engine: any TerminalEngineProtocol) {
        shared = engine
    }
}
