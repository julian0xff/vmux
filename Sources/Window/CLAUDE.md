# Window

Window management, chrome, and AppKit portal layer.

- `TerminalWindowPortal.swift` + `BrowserWindowPortal.swift` — AppKit NSView trees that bypass SwiftUI for Metal-rendered terminals and WKWebViews
- `WindowAccessor.swift` — bridges SwiftUI to NSWindow
- `WindowDecorationsController.swift` — traffic light controls
- `WindowToolbarController.swift` — NSToolbar management
- `WindowDragHandleView.swift` — custom titlebar dragging
