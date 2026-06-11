---
task-name: migrate module-commands-code-to-record onto split-statements
status: completed
created: 2026-06-11
updated: 2026-06-11
completed: 2026-06-11
---

# Migrate `module-commands-code-to-record` onto `split-statements`

## Task from user (original)

Migrate module-commands-code-to-record onto split-statements (AST-based),
removing the line-based forward-fill and trailing-} trimming

## Task description (extended version)

Follow-up to todo/20260611-2110-fix-module-commands-code-to-record.md
(the "Better" fix direction there). The command currently rebuilds command
blocks from lines: regex on `def` lines, a manual forward-fill of command
names, `group-by`, and trailing-`}` trimming via `reverse | skip until ...`.
The forward-fill already broke once (`append null` no-op) and was patched
minimally; the trimming stays fragile.

`split-statements` (commands.nu) already returns top-level statements with
byte spans, with attributes and comments excluded from the statement text.
Verified live: for `join-next` (which has `@example` attributes above it)
it returns exactly the `def` block. So the whole pipeline collapses to:
filter `def` statements, key by extracted command name.

## Requirements

- [ ] Same keys as today: command name via `extract-command-name`,
      `main` renamed via `replace-main-with-module-name`
- [ ] Values are the full `def` blocks (attributes/comments excluded)
- [ ] Known acceptable change: each block loses its trailing newline
      (`split-statements` trims; old `to text` added one). No internal or
      workspace callers; tests use `=~`
- [ ] Strip CRLF before `split-statements` on Windows, same one-liner as
      `list-module-commands` (byte offsets shift otherwise)
- [ ] `nu toolkit.nu test` passes; existing tests already cover leading
      `use` lines, quoted names, multiple commands — add nothing unless
      something fails

## Implementation plan

- [ ] Replace the body of `module-commands-code-to-record` (commands.nu:795)
      with the split-statements pipeline:

      ```nu
      open $module_path -r
      | if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
      | split-statements
      | where statement =~ '^(export )?def '
      | each {|s|
          let name = $s.statement | lines | first
          | extract-command-name
          | replace-main-with-module-name $module_path
          {$name: $s.statement}
      }
      | into record
      ```

- [ ] Run `nu toolkit.nu test`, fix fallout if any

## Affected files

- Existing files: `dotnu/dotnu/commands.nu`
- New files: none expected

## Execution result

**Date:** 2026-06-11

**Modified files:**
- `dotnu/commands.nu` — body of `module-commands-code-to-record` replaced
  with the split-statements pipeline exactly as planned (~30 lines -> 11).
  Forward-fill and trailing-`}` trimming are gone.

**Summary:**
All requirements met on the first run: `nu toolkit.nu test` 75/75, no test
changes needed. Live check on `tests/assets/module-say/say/mod.nu` returns
the same blocks as before, minus the trailing newline per block (the
documented acceptable change).
