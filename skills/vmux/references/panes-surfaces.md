# Panes and Surfaces

Split layout, surface creation, focus, move, and reorder.

## Inspect

```bash
vmux list-panes
vmux list-pane-surfaces --pane pane:1
```

## Create Splits/Surfaces

```bash
vmux new-split right --panel pane:1
vmux new-surface --type terminal --pane pane:1
vmux new-surface --type browser --pane pane:1 --url https://example.com
```

## Focus and Close

```bash
vmux focus-pane --pane pane:2
vmux focus-panel --panel surface:7
vmux close-surface --surface surface:7
```

## Move/Reorder Surfaces

```bash
vmux move-surface --surface surface:7 --pane pane:2 --focus true
vmux move-surface --surface surface:7 --workspace workspace:2 --window window:1 --after surface:4
vmux reorder-surface --surface surface:7 --before surface:3
```

Surface identity is stable across move/reorder operations.
