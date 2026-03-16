# vmux Modularization Plan

**Baseline tag:** `pre-modularization` (commit `290de24`)
**Created:** 2026-03-16
**Total codebase:** ~94,000 lines across 55 Swift files, single flat target `GhosttyTabs`

---

## Goal

Split the monolithic app target into local Swift packages so that multiple AI agents can work on different domains (Terminal, Browser, Sidebar, Socket IPC, Settings, etc.) simultaneously without merge conflicts.

## Current God Files

| File | Lines | Concerns |
|------|-------|----------|
| `TerminalController.swift` | 14,128 | Socket server + ALL command handlers |
| `ContentView.swift` | 13,459 | Sidebar, command palette, drag-drop, theming, window chrome |
| `AppDelegate.swift` | 11,475 | Lifecycle, menus, keyboard routing, window mgmt, utilities |
| `GhosttyTerminalView.swift` | 8,731 | Ghostty C API, TerminalSurface, Metal rendering |
| `BrowserPanelView.swift` | 5,793 | Browser UI + omnibar |
| `Workspace.swift` | 5,316 | Per-tab state, panels, sidebar metadata |
| `vmuxApp.swift` | 5,085 | App entry, settings UI, all @AppStorage |
| `BrowserPanel.swift` | 5,073 | Browser model, WK delegates, settings |
| `TabManager.swift` | 4,547 | Workspace collection, settings enums |

## Critical Coupling Hotspots

- **`AppDelegate.shared`** — accessed from 15+ files. Circular: AppDelegate ↔ TabManager ↔ Workspace
- **`GhosttyApp.shared`** — accessed from 11 files
- **`TerminalController.shared`** — directly mutates Workspace properties from socket commands
- **NotificationCenter** — 90+ post/observe calls across 16 files

## Target Architecture

```
Packages/
├── VmuxCore/         # Layer 0: protocols, pure types, settings enums
├── VmuxSession/      # Layer 1: session persistence (Codable types)
├── VmuxSocket/       # Layer 1: socket IPC server + command handlers
├── VmuxTerminal/     # Layer 2: Ghostty wrapper, TerminalSurface, portals
├── VmuxBrowser/      # Layer 2: WKWebView panel, omnibar, browser portals
└── VmuxUpdate/       # Layer 2: Sparkle update flow
```

### Dependency DAG

```
           GhosttyKit.xcframework
                    │
                VmuxCore
              (protocols, types)
                    │
     ┌──────┬──────┼──────┬──────────┐
     │      │      │      │          │
VmuxSession VmuxSocket VmuxTerminal VmuxBrowser VmuxUpdate
     │      │      │      │          │
     └──────┴──────┴──────┴──────────┘
                    │
              GhosttyTabs (app target)
```

## Key Design Decisions

### Breaking Circular Dependencies via Protocols

**`AppServicesProtocol`** (in VmuxCore) — interface for what modules need from AppDelegate:
- `openNewMainWindow`, `focusMainWindow`, `openBrowserAndFocusAddressBar`
- `toggleNotificationsPopover`, `openTemplateCreationDialog`
- `attachUpdateAccessory`, `applyWindowDecorations`
- `registerMainWindow`

**`TerminalEngineProtocol`** (in VmuxCore) — interface for what modules need from GhosttyApp:
- `defaultBackgroundColor`, `defaultBackgroundOpacity`, `config`
- `reloadConfiguration`, `handleAction`, `tick`

**`SocketTabManagerProtocol`** (in VmuxSocket) — interface for socket commands to reach TabManager:
- Compiler-guided extraction: change the type, fix every error = complete protocol

### Package Contents

**VmuxCore** (everything depends on this):
- `Panel` protocol, `PanelType`, `FocusFlashPattern`
- `SidebarFolderModel`, `SidebarFolderStore`, `SidebarSelectionState`
- `KeyboardShortcutSettings`, `GhosttyConfig`
- `SidebarSelection` enum (extracted from ContentView.swift:12733)
- `Backport` utilities
- `AppServicesProtocol`, `TerminalEngineProtocol`

**VmuxSession**: `SessionPersistence.swift` (pure Codable snapshot types)

**VmuxSocket**: `SocketControlSettings`, socket server infrastructure, command handlers

**VmuxTerminal**: `GhosttyApp`, `TerminalSurface`, `GhosttySurfaceScrollView`, `TerminalWindowPortal`, `SurfaceSearchOverlay`

**VmuxBrowser**: `BrowserPanel`, `BrowserPanelView`, `VmuxWebView`, `BrowserWindowPortal`, `BrowserSearchOverlay`, `BrowserFindJavaScript`

**VmuxUpdate**: All `Sources/Update/*.swift`

**Stays in app target** (integration layer):
- `vmuxApp.swift`, `AppDelegate.swift`, `TabManager.swift`, `Workspace.swift`, `ContentView.swift`

## Phased Migration

### Phase 0: Infrastructure Setup
- Create `Packages/VmuxCore/` with `Package.swift`
- Add local package reference in xcodeproj
- Move `Panel.swift` + `Backport.swift` to VmuxCore (add `public`)
- **Verify:** build compiles

### Phase 1: Extract Pure Settings to VmuxCore
- Move `SidebarFolderModel.swift`, `SidebarFolderStore.swift` to VmuxCore
- Move `KeyboardShortcutSettings.swift` to VmuxCore
- Move `GhosttyConfig.swift` to VmuxCore
- Extract `SidebarSelection` enum from ContentView.swift → VmuxCore
- Move `SidebarSelectionState.swift` to VmuxCore
- **Verify:** build + unit tests

### Phase 2: Extract VmuxSession
- Create `Packages/VmuxSession/Package.swift` (depends on VmuxCore, Bonsplit)
- Move `SessionPersistence.swift` to VmuxSession
- Add `import VmuxSession` where snapshot types are used
- **Verify:** build

### Phase 3: Extract VmuxSocket
- Create `Packages/VmuxSocket/Package.swift` (depends on VmuxCore)
- Move `SocketControlSettings.swift` to VmuxSocket
- Define `SocketTabManagerProtocol` + `SocketWorkspaceProtocol`
- Make `TabManager` conform to `SocketTabManagerProtocol` (extension in app target)
- Move socket server infrastructure (~2,000 lines) first
- Move command handlers progressively (compiler-guided by protocol)
- **Verify:** build at each sub-step

### Phase 4: Extract VmuxUpdate
- Create `Packages/VmuxUpdate/Package.swift` (depends on VmuxCore, Sparkle)
- Move `TitlebarControlsStyle` to VmuxCore first
- Move all `Sources/Update/*.swift` to VmuxUpdate
- **Verify:** build

### Phase 5: Extract VmuxTerminal (highest risk)
- Define `TerminalEngineProtocol` in VmuxCore
- Add `extension GhosttyApp: TerminalEngineProtocol` in app target
- Replace all 11 files' `GhosttyApp.shared` calls with protocol reference
- Create `Packages/VmuxTerminal/Package.swift` (depends on VmuxCore, Bonsplit, GhosttyKit)
- Move `GhosttyApp`, `TerminalSurface`, `GhosttySurfaceScrollView`, `TerminalWindowPortal`, `SurfaceSearchOverlay`
- **Verify:** build (budget extra time for @MainActor mismatches)

### Phase 6: Extract VmuxBrowser
- Create `Packages/VmuxBrowser/Package.swift` (depends on VmuxCore, VmuxTerminal)
- Replace `GhosttyApp.shared` calls in BrowserPanel with protocol injection
- Move all browser files
- **Verify:** build

### Phase 7: Split God Files Within App Target (ongoing)
- ContentView.swift → SidebarView, CommandPaletteView, DragDropInfra, WindowChrome
- AppDelegate.swift → ShortcutRouter, WindowLifecycleService, CLIInstallService
- TabManager.swift → extract settings enums to VmuxCore
- Workspace.swift → extract sidebar telemetry types to VmuxCore

## Risks

1. **GhosttyKit.xcframework in SPM** — must be a binary target dep of VmuxCore. Test in Phase 0.
2. **@MainActor boundary violations** — moving GhosttyApp may trigger concurrency errors. Phase 5.
3. **14,128-line TerminalController** — move incrementally, not all at once. Phase 3.
4. **xcodeproj surgery** — add packages via Xcode UI, not hand-editing pbxproj.

## Agent Parallelism After Completion

| Agent | Package/Area | Primary Files |
|-------|-------------|---------------|
| Agent A | Socket IPC | `Packages/VmuxSocket/` |
| Agent B | Browser panel | `Packages/VmuxBrowser/` |
| Agent C | Terminal/Ghostty | `Packages/VmuxTerminal/` |
| Agent D | Update system | `Packages/VmuxUpdate/` |
| Agent E | Sidebar UI | `Sources/UI/Sidebar/` |
| Agent F | Settings | `Sources/UI/Settings/` |
