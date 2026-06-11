---
task-name: fix hidden cprint dependency in embeds-capture commands
status: draft
created: 2026-06-11
updated: 2026-06-11
---

# `embeds-capture-start/stop` fail without nu-goodies: `cprint` is not defined in dotnu

## Problem

`commands.nu` calls `cprint` (lines 507, 551, 559) but never defines or
imports it. At parse time Nushell treats the bare word as an external
command, so in any session where nu-goodies' `cprint` is not already in
scope the commands fail at runtime. Found during live testing for
todo/20260611-2057-test-dotnu-agent-commands.md (Nushell 0.113.1, 7763f51).

It currently works only in the author's interactive sessions because the
autoload does `overlay use ~/repos/nu-goodies/nu-goodies` before `use dotnu`.
Agents and CI run `nu -c` / bare `nu -n`, where it breaks.

## Repro

```nu
nu -n -c 'use dotnu/ *; embeds-capture-start /tmp/x.nu'
# Error: nu::shell::external_command — Command `cprint` not found
```

(`nu -c` in the cozy container fails the same way — the overlay is only
loaded for interactive sessions.)

## Fix direction

Replace `cprint` with plain `print` (drop the `*bold*` markup), or vendor
a minimal cprint. These are the only 3 call sites.

## Related quirks found in the same live-REPL test (fold in if cheap)

- `embeds-capture-start` records **itself** into the capture file: the
  hook filter `if ($in !~ 'dotnu capture')` matches neither
  `embeds-capture-start ...` nor `dotnu embeds-capture-start ...`.
- `embed-add` strips itself from the recorded command with regex
  `'\| ?dotnu embed-add.*$'` — works only when invoked as
  `dotnu embed-add`; a direct `embed-add` call leaves
  `... | embed-add | print $in` in the capture file, so replaying the
  file re-runs embed-add.
- `get-command-from-hist` with plaintext history prints
  "txt history file format is not supported" and returns null; the
  caller then dies on `| get previous`. Should be a clear
  `error make` instead (fail fast at the source).
