---
task-name: fix module-commands-code-to-record misalignment
status: draft
created: 2026-06-11
updated: 2026-06-11
---

# Fix `module-commands-code-to-record`: forward-fill drops leading nulls

## Problem

Broken for any module that has lines before the first `def`
(`use` statements, comments) — i.e. almost every real module.
Found during live testing for todo/20260611-2057-test-dotnu-agent-commands.md
(Nushell 0.113.1, commit 7763f51).

Root cause: in the manual forward-fill (`commands.nu:810-819`)
`$acc | append (if $i == null { $prev } else { $i })` appends `$prev`,
which is `null` for all lines before the first `def`. In current Nushell
`append null` is a **no-op** (`[1 2] | append null | length` == 2), so the
forward-filled list is shorter than the line table and `merge` misaligns
every row: command names shift onto the wrong lines, bodies get attached
to the wrong commands.

The existing comment at `commands.nu:812` explains this code already
replaced `std scan` because of a null-seed change — the workaround itself
hit a second null-handling change.

## Repro

```nu
use dotnu/commands.nu *
module-commands-code-to-record tests/assets/module-say/say/mod.nu
# actual:   {hi: "", say: "    $\"hi ($where)!\"\n}\n"}   (say got hi's body)
# expected: hi -> full hi block, say -> main block
```

Unit tests pass because their fixtures start with `def` on line 1.
Add a test fixture with a comment/`use` line before the first `def`.

## Fix direction

- Minimal: make the fill length-preserving, e.g. wrap each element
  (`append [$prev]`-style or build via `each` with a mutable last-seen).
- Better (justified AST migration): rebuild on `split-statements`, which
  already returns statements with byte positions — pick `def` statements
  and slice the source by spans instead of line heuristics. This also
  fixes the fragile trailing-`}` trimming (`reverse | skip until ...`).
