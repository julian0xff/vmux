# Workspace

Workspace and tab model layer.

- `TabManager.swift` — manages ordered [Workspace] array, selection, navigation history, split operations
- `Workspace.swift` — per-tab state: owns BonsplitController, panels, sidebar metadata
- `WorkspaceContentView.swift` — renders a workspace via BonsplitView
- `WorkspaceTemplateSettings.swift` + `TemplateCreationView.swift` — workspace templates
- `TabManager+SocketProtocol.swift` + `Workspace+SocketProtocol.swift` — VmuxSocket protocol conformances
