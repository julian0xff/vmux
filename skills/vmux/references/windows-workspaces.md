# Windows and Workspaces

Window/workspace lifecycle and ordering operations.

## Inspect

```bash
vmux list-windows
vmux current-window
vmux list-workspaces
vmux current-workspace
```

## Create/Focus/Close

```bash
vmux new-window
vmux focus-window --window window:2
vmux close-window --window window:2

vmux new-workspace
vmux select-workspace --workspace workspace:4
vmux close-workspace --workspace workspace:4
```

## Reorder and Move

```bash
vmux reorder-workspace --workspace workspace:4 --before workspace:2
vmux move-workspace-to-window --workspace workspace:4 --window window:1
```
