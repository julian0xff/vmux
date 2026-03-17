# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Initial setup

```bash
./scripts/setup.sh    # initialize submodules and build GhosttyKit
```

## Architecture

vmux is a macOS terminal multiplexer built with Swift/SwiftUI, embedding Ghostty (Zig-compiled) as the terminal engine via GhosttyKit.xcframework.

### Package structure

The app is split into local Swift packages under `Packages/` plus the main app target:

```
GhosttyKit.xcframework (Zig binary, built from ghostty submodule)
         │
     VmuxCore           ← Layer 0: protocols, types, settings (no app deps)
         │
  ┌──────┼──────────┬──────────┬──────────┐
  │      │          │          │          │
VmuxSession  VmuxSocket  VmuxTerminal  VmuxUpdate
(persistence) (IPC types) (engine bridge) (Sparkle)
  │      │          │          │          │
  └──────┴──────────┴──────────┴──────────┘
                    │
           GhosttyTabs (app target)
      imports all packages + Bonsplit + MarkdownUI
```

**VmuxCore** — Panel protocol, Backport utilities, SidebarFolderModel/Store, SidebarSelection, KeyboardShortcutSettings, GhosttyConfig, TerminalEngineProtocol, GhosttyNotifications, FocusLogStore

**VmuxSession** — SessionPersistence (all Codable snapshot types). Depends on VmuxCore + Bonsplit.

**VmuxSocket** — SocketControlSettings, SocketTabManagerProtocol/SocketWorkspaceProtocol (22 methods, 8 properties). Depends on VmuxCore.

**VmuxTerminal** — TerminalEngine singleton accessor (protocol bridge to GhosttyApp). Depends on VmuxCore.

**VmuxUpdate** — Full Sparkle update flow (11 files: controller, delegate, driver, view model, UI). Depends on VmuxCore + Sparkle.

### App target organization

```
Sources/
├── vmuxApp.swift              # @main entry, @StateObject ownership, settings UI
├── AppDelegate.swift          # Lifecycle, menus, keyboard routing, window mgmt
├── ContentView.swift          # Main window: sidebar, command palette, drag-drop
├── TerminalController.swift   # Unix socket server, all V1/V2 command handlers
├── GhosttyTerminalView.swift  # Ghostty C API: GhosttyApp, TerminalSurface, NSView
├── TabManager.swift           # Workspace collection, selection, navigation
├── Workspace.swift            # Per-workspace state, panels, BonsplitDelegate
├── Panels/                    # Panel protocol impls (Terminal, Browser, Markdown)
├── Services/                  # Extracted from AppDelegate: InputRouting, MenuBar, etc.
├── UI/                        # Extracted from ContentView: CommandPalette, DragDrop, etc.
├── Find/                      # In-terminal and in-browser search overlays
└── Update/                    # UpdateTitlebarAccessory (kept in app target, cross-cutting)
```

### Key singletons and state flow

- **GhosttyApp.shared** — Ghostty C runtime (`ghostty_app_t`). Accessed via `TerminalEngine.shared?` (protocol) from packages.
- **TerminalController.shared** — Unix socket server. Holds weak `TabManager` ref, mutates Workspace from socket commands.
- **AppDelegate.shared** — Multi-window management. `mainWindowContexts` maps windows to their TabManager/SidebarState.
- **TabManager** — One per window. Owns `[Workspace]` array. Created as `@StateObject` in vmuxApp, injected via `@EnvironmentObject`.
- **Workspace** — One per sidebar tab. Owns `BonsplitController` (split layout) and `[UUID: any Panel]`.

### Submodules

- **ghostty** (`manaflow-ai/ghostty` fork) — Ghostty terminal engine source, builds GhosttyKit.xcframework
- **vendor/bonsplit** (`julian0xff/bonsplit`) — Split-pane tab bar layout engine (`@Observable`)
- **homebrew-vmux** (`manaflow-ai/homebrew-vmux`) — Homebrew cask (used by CI release workflow)

### Portal architecture

Terminal (`TerminalWindowPortal.swift`) and browser (`BrowserWindowPortal.swift`) NSViews can't be hosted directly in SwiftUI. "Portal" files use associated-object tricks to attach NSView trees to NSWindow slots, bypassing the normal view hierarchy. These are the most architecturally unusual part of the codebase.

## Local dev

Always use tagged builds. Never run bare `xcodebuild` or `open` an untagged `vmux DEV.app`.

```bash
./scripts/reload.sh --tag <tag>     # kill + build + launch Debug app
./scripts/reloadp.sh                # kill + launch Release app
./scripts/reloads.sh                # kill + launch as "vmux STAGING"
./scripts/reload2.sh --tag <tag>    # reload both Debug + Release
```

Build-only (no launch):
```bash
xcodebuild -project GhosttyTabs.xcodeproj -scheme vmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/vmux-<tag> build
```

Rebuild GhosttyKit (Release optimizations required):
```bash
cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast
```

When reporting a tagged reload in chat, use a clickable file:// link:
```markdown
=======================================================
[vmux DEV <tag>.app](file:///Users/iulian/Library/Developer/Xcode/DerivedData/vmux-<tag>/Build/Products/Debug/vmux%20DEV%20<tag>.app)
=======================================================
```

## Debug event log

All debug events go to a unified log in DEBUG builds:

```bash
tail -f "$(cat /tmp/vmux-last-debug-log-path 2>/dev/null || echo /tmp/vmux-debug.log)"
```

- Tagged builds: `/tmp/vmux-debug-<tag>.log`
- Implementation: `vendor/bonsplit/Sources/Bonsplit/Public/DebugEventLog.swift`
- Use `dlog("message")` — must be wrapped in `#if DEBUG` / `#endif`
- `DebugEventLog.shared.dump()` flushes the ring buffer to file

## Pitfalls

- **Custom UTTypes** for drag-and-drop must be declared in `Resources/Info.plist` under `UTExportedTypeDeclarations`.
- Do not add an app-level display link or manual `ghostty_surface_draw` loop; rely on Ghostty wakeups/renderer to avoid typing lag.
- **Typing-latency-sensitive paths:**
  - `WindowTerminalHostView.hitTest()` in `TerminalWindowPortal.swift`: called on every event. All divider/sidebar/drag routing is gated to pointer events only.
  - `TabItemView` in `ContentView.swift`: uses `Equatable` + `.equatable()` to skip body re-evaluation during typing. Do not add `@EnvironmentObject`, `@ObservedObject` (besides `tab`), or `@Binding` without updating `==`.
  - `TerminalSurface.forceRefresh()` in `GhosttyTerminalView.swift`: called on every keystroke. No allocations, file I/O, or formatting.
- **Terminal find layering:** `SurfaceSearchOverlay` must mount from `GhosttySurfaceScrollView` (AppKit portal layer), not SwiftUI panel containers.
- **Submodule safety:** Always push submodule commits to remote `main` BEFORE committing the pointer in the parent repo. Never commit on detached HEAD. Verify: `cd <submodule> && git merge-base --is-ancestor HEAD origin/main`.
- **All user-facing strings must be localized.** Use `String(localized: "key.name", defaultValue: "English text")`. Keys go in `Resources/Localizable.xcstrings`.
- **GhosttyKit.xcframework cannot be a binary target in SPM packages** — it causes module conflicts with the same xcframework linked at the Xcode project level. Files referencing Ghostty C types must stay in the app target.
- **Moving ObservableObject types across module boundaries can crash SwiftUI.** The VmuxBrowser extraction was reverted because moving `ObservableObject` classes to a separate package caused use-after-free in `@Observable` tracking during SwiftUI's environment modifier system.

## Testing policy

**Never run tests locally.** All tests run via GitHub Actions or on the VM.

- **Unit tests:** `xcodebuild -scheme vmux-unit` is safe (no app launch), but prefer CI
- **E2E / UI tests:** trigger via `gh workflow run test-e2e.yml`
- **Python socket tests (tests_v2/):** connect to a running vmux socket. Never launch untagged `vmux DEV.app`.

## Test quality policy

- Tests must verify observable runtime behavior, not source code text or AST patterns.
- Do not add tests that grep source files or read project metadata.
- If no meaningful behavioral test is practical, skip the fake test and state that explicitly.

## Regression test commit policy

Two-commit structure: (1) Add failing test only → CI goes red. (2) Add fix → CI goes green.

## Socket command threading policy

- Do not use `DispatchQueue.main.sync` for high-frequency telemetry commands (`report_*`, `ports_kick`, metadata updates).
- Parse/validate off-main. Dedupe/coalesce off-main. Schedule minimal UI mutation with `.main.async`.
- Commands that directly manipulate AppKit/Ghostty UI state may run on main actor.

## Socket focus policy

- Socket/CLI commands must not steal macOS app focus.
- Only explicit focus-intent commands (`window.focus`, `workspace.select`, `surface.focus`, etc.) may mutate focus/selection.

## Ghostty submodule workflow

```bash
cd ghostty
git checkout -b <branch>
# make changes, commit
git push manaflow <branch>
cd .. && git add ghostty && git commit -m "Update ghostty submodule"
```

## Known limitations

- **Equalize splits with many panes (6+):** Uses two-pass convergence for nested NSSplitView constraints. With 6+ panes, a second press may be needed. Model positions are always correct — this is an NSSplitView constraint propagation limitation.
- **VmuxBrowser package extraction blocked:** Moving `ObservableObject` types from the app target to a separate SPM package causes SwiftUI observation crashes. Browser files remain in the app target. See `MODULARIZATION.md` for details.

## Release

```bash
./scripts/bump-version.sh          # bump minor
./scripts/bump-version.sh patch    # bump patch
./scripts/bump-version.sh 1.0.0    # set specific version
```

Updates both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (build number, required for Sparkle).

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

Release workflow builds, signs, notarizes, and uploads `vmux-macos.dmg`.
