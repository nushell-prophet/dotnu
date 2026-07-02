---
session: 9b061696-a884-40ff-a2d6-dd91aa2cb639
---

# Refactoring audit of dotnu/commands.nu — remaining items

Full-file audit (2026-07-02). The embeds group, examples group, split-statements fix, extract-command-code §4.1–4.3, and dead-code removal are all done and committed. What remains: one strategic decision (§4.4) and the minor items (§6).

## 4.4 strategic question: two extractors

`extract-command-code` (+ `dummy-command`, ~120 lines of view-source templating) and `extract-module-command` (runtime, newer) overlap heavily. If the vars-preservation / `--set-vars` workflow migrated onto the runtime extractor, the whole `dummy-command` machinery could retire. Big reduction, but it changes a public command's behavior — needs a decision, not a drive-by.

## 6. minor

- `list-module-exports` / `list-module-interface` end with `print 'No command found'` and return nothing (`commands.nu:380-383`, `commands.nu:399-402`) — a `nothing -> list<string>` command that sometimes prints breaks composition. Return the empty list; let interactive callers print.
- `dependencies` re-runs `help commands` once per file via `list-module-commands` (`commands.nu:1023`); could be computed once per `dependencies` call and passed down. Only matters on many-file modules.
- `nu-completion-command-name` hardcodes `' extract-command-code '` in its context regex (`commands.nu:963`) — attaching it to any other command's parameter silently misparses.
- Stale in-code todo at `commands.nu:405` (`# todo: make configuration like --autocommit in file itself`) — implement or move here.
