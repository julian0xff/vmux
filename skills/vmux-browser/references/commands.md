# Command Reference (vmux Browser)

This maps common `agent-browser` usage to `vmux browser` usage.

## Direct Equivalents

- `agent-browser open <url>` -> `vmux browser open <url>`
- `agent-browser goto|navigate <url>` -> `vmux browser <surface> goto|navigate <url>`
- `agent-browser snapshot -i` -> `vmux browser <surface> snapshot --interactive`
- `agent-browser click <ref>` -> `vmux browser <surface> click <ref>`
- `agent-browser fill <ref> <text>` -> `vmux browser <surface> fill <ref> <text>`
- `agent-browser type <ref> <text>` -> `vmux browser <surface> type <ref> <text>`
- `agent-browser select <ref> <value>` -> `vmux browser <surface> select <ref> <value>`
- `agent-browser get text <ref>` -> `vmux browser <surface> get text <ref-or-selector>`
- `agent-browser get url` -> `vmux browser <surface> get url`
- `agent-browser get title` -> `vmux browser <surface> get title`

## Core Command Groups

### Navigation

```bash
vmux browser open <url>                        # opens in caller's workspace (uses VMUX_WORKSPACE_ID)
vmux browser open <url> --workspace <id|ref>   # opens in a specific workspace
vmux browser <surface> goto <url>
vmux browser <surface> back|forward|reload
vmux browser <surface> get url|title
```

> **Workspace context:** `browser open` targets the workspace of the terminal where the command is run (via `VMUX_WORKSPACE_ID`), even if a different workspace is currently focused. Use `--workspace` to override.

### Snapshot and Inspection

```bash
vmux browser <surface> snapshot --interactive
vmux browser <surface> snapshot --interactive --compact --max-depth 3
vmux browser <surface> get text body
vmux browser <surface> get html body
vmux browser <surface> get value "#email"
vmux browser <surface> get attr "#email" --attr placeholder
vmux browser <surface> get count ".row"
vmux browser <surface> get box "#submit"
vmux browser <surface> get styles "#submit" --property color
vmux browser <surface> eval '<js>'
```

### Interaction

```bash
vmux browser <surface> click|dblclick|hover|focus <selector-or-ref>
vmux browser <surface> fill <selector-or-ref> [text]   # empty text clears
vmux browser <surface> type <selector-or-ref> <text>
vmux browser <surface> press|keydown|keyup <key>
vmux browser <surface> select <selector-or-ref> <value>
vmux browser <surface> check|uncheck <selector-or-ref>
vmux browser <surface> scroll [--selector <css>] [--dx <n>] [--dy <n>]
```

### Wait

```bash
vmux browser <surface> wait --selector "#ready" --timeout-ms 10000
vmux browser <surface> wait --text "Done" --timeout-ms 10000
vmux browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000
vmux browser <surface> wait --load-state complete --timeout-ms 15000
vmux browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

### Session/State

```bash
vmux browser <surface> cookies get|set|clear ...
vmux browser <surface> storage local|session get|set|clear ...
vmux browser <surface> tab list|new|switch|close ...
vmux browser <surface> state save|load <path>
```

### Diagnostics

```bash
vmux browser <surface> console list|clear
vmux browser <surface> errors list|clear
vmux browser <surface> highlight <selector>
vmux browser <surface> screenshot
vmux browser <surface> download wait --timeout-ms 10000
```

## Agent Reliability Tips

- Use `--snapshot-after` on mutating actions to return a fresh post-action snapshot.
- Re-snapshot after navigation, modal open/close, or major DOM changes.
- Prefer short handles in outputs by default (`surface:N`, `pane:N`, `workspace:N`, `window:N`).
- Use `--id-format both` only when a UUID must be logged/exported.

## Known WKWebView Gaps (`not_supported`)

- `browser.viewport.set`
- `browser.geolocation.set`
- `browser.offline.set`
- `browser.trace.start|stop`
- `browser.network.route|unroute|requests`
- `browser.screencast.start|stop`
- `browser.input_mouse|input_keyboard|input_touch`

See also:
- [snapshot-refs.md](snapshot-refs.md)
- [authentication.md](authentication.md)
- [session-management.md](session-management.md)
