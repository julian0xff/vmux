# Panels

Panel implementations for the three content types.

- `BrowserPanel.swift` (5k lines) — wraps WKWebView with navigation, history, find, downloads, and theme integration
- `BrowserPanelView.swift` (5.7k lines) — SwiftUI view with omnibar
- `TerminalPanel.swift` — wraps TerminalSurface as a Panel
- `MarkdownPanel.swift` — renders markdown with file watching
- `VmuxWebView.swift` — WKWebView subclass
- `PanelContentView.swift` — routes to the correct view by panel type
