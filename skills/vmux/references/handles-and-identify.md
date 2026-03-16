# Handles and Identify

Use `identify` and short handles for deterministic automation targeting.

## Handle Inputs

Most v2-backed commands accept:
- UUID
- short ref (`window:N`, `workspace:N`, `pane:N`, `surface:N`)
- index (where legacy/index-based commands still allow it)

## Self Identify

```bash
vmux identify --json
```

Returns current focused topology plus optional caller resolution.

## Caller Override

```bash
vmux identify --workspace workspace:2
vmux identify --workspace workspace:2 --surface surface:8
```

Useful for agents that need to route relative actions from a known caller anchor.

## Output Shaping

```bash
vmux --json identify                 # refs-first output
vmux --json --id-format both identify
vmux --json --id-format uuids identify
```
