---
session: 9b061696-a884-40ff-a2d6-dd91aa2cb639
---

# Refactoring audit of dotnu/commands.nu — remaining items

Full-file audit (2026-07-02). The embeds group, examples group, split-statements fix, extract-command-code §4.1–4.3, the two-extractors consolidation (§4.4), the per-file `help commands` fix (§6, now computed once per `dependencies` call), and dead-code removal are all done and committed. What remains: the remaining minor items (§6).

## 6. minor

- `list-module-exports` / `list-module-interface` end with `print 'No command found'` and return nothing (`commands.nu:380-383`, `commands.nu:399-402`) — a `nothing -> list<string>` command that sometimes prints breaks composition. Return the empty list; let interactive callers print.
- ~~Stale in-code todo at `commands.nu:405` (`# todo: make configuration like --autocommit in file itself`) — implement or move here.~~ Done: dropped `--auto-commit` and `embeds-setup` entirely; `embed-add` now takes `--capture-path` (an `--env` def, so it sticks for the session), which replaced the whole `embeds-setup` config surface.
