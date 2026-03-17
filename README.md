# vmux

A personal fork of [vmux](https://github.com/manaflow-ai/vmux) with custom enhancements.

## What's different

- Sidebar folder system (VS Code-style grouping with nested folders, drag-and-drop, Cmd+G to group)
- Template workspaces (multi-pane layouts with auto-launched agents)
- Cross-workspace panel drag (move terminals between workspaces)
- Workspace merge (combine workspaces via context menu)
- Sidebar theme matching (reads Ghostty terminal colors)
- Workspace names show last folder name instead of full path
- Green V app icon

## Known limitations

- **Equalize splits with many panes (6+):** The equalize splits shortcut (Cmd+Ctrl+=) may need a second press to fully converge with deeply nested split layouts (6+ panes). This is due to NSSplitView minimum size constraint propagation in nested hierarchies.
