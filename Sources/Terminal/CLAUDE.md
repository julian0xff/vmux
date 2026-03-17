# Terminal

Terminal rendering engine and socket server.

- `GhosttyTerminalView.swift` (8.7k lines) — wraps the Ghostty C API: GhosttyApp singleton, TerminalSurface lifecycle, GhosttyNSView (input), GhosttySurfaceScrollView, Metal rendering, and all C callback implementations
- `TerminalController.swift` (14k lines) — Unix socket server handling all V1/V2 commands (workspace, pane, surface, browser, notification operations)
