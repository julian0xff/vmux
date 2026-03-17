# VmuxUpdate

Sparkle auto-update subsystem (11 files).

- `UpdateController.swift` — manages update lifecycle
- `UpdateDriver.swift` — handles user interaction flow
- `UpdateViewModel.swift` — exposes state to SwiftUI
- `UpdateDelegate.swift` — bridges Sparkle callbacks
- `UpdateBadge.swift`, `UpdatePill.swift`, `UpdatePopoverView.swift` — UI components
- `UpdateTestSupport.swift`, `UpdateTestURLProtocol.swift` — test support
- Depends on VmuxCore + Sparkle
