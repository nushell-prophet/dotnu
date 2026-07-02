---
task-name: runtime extract command with deps into one embedded file
status: completed
created: 2026-06-11
updated: 2026-07-02
completed: 2026-07-02
related_files:
  - dotnu/commands.nu
---

# Runtime extraction of a command with its dependency cascade into one file

## Task from user (original)

ок, согласен что на чужом коде его просто нельзя исползовать. В новой команде нужно будет добавить проверку что export-env нет в коде. И если есть - то нужно добавить флаг.

А так напиши todo на создание команды, которая загружает выбранную команду из модуля в память и каскадно выгружает все связанные команды, чтобы создать один файл в котором все embeded.

Возможно такое?

*(English translation: OK, I agree it just can't be used on someone else's code. The new command will need a check that there is no `export-env` in the code, and if there is — a flag to allow it. So write a todo for a command that loads a chosen command from a module into memory and cascade-dumps all related commands, to create one file where everything is embedded. Is that possible?)*

## Task description

Yes, possible. A runtime analog of `extract-command-code`: instead of parsing one script file, import the module into a clean `nu -n` and dump command bodies via `view source`.

Why, when `extract-command-code` exists: static parsing works on a single script file. Runtime introspection sees the module the way Nushell sees it after resolution — `export use` chains, submodules, `main` renaming. This is the path to a self-contained file from any module.

Caveat on approach: the temp-copy rewrite below has grown (defs + uses + collision and path checks). Nushell doing the resolution is still the win, but if the rewrite grows further, static assembly becomes competitive again.

## Mechanics (probed 2026-06-11 and 2026-07-02, nu 0.113.1)

1. **Safety scan before import.** `use` runs `export-env` blocks — the module's own and those of transitively imported modules. That is the only channel of arbitrary code execution at import: top-level code in a module is a parse error; `const` and attribute evaluation happen at parse time but are limited to const-safe commands. So before importing: AST scan (not regex) of all module `.nu` files for `export-env`. Found → error with the file list; `--allow-export-env` continues anyway. Note: even with the flag, a command that reads `$env` values set by `export-env` extracts fine but breaks at runtime — the output is not semantically self-contained. Document this.

2. **Export-ified temp copy.** Private `def`s are invisible from outside: not in `scope commands`, `view source` fails on them (verified). Workaround: copy the module directory to temp and rewrite top-level `def` → `export def` in all `.nu` files (by AST; bodies untouched).
   - **Correction (verified 2026-07-02):** rewriting `def` alone is not enough. A command pulled into a file with a plain `use` (private import) stays invisible after glob import, even when its own file already exports it. Top-level local `use` → `export use` must be rewritten too. Only for the module's own files — imports of external modules (`std` etc.) stay untouched and are reproduced as `use` lines in the output file.
   - Rewrite top-level statements only; a `def` inside a command body must not be touched.
   - **Collision check (verified):** glob-importing the same name from two files shadows silently — last wins, no error. After export-ification, two private helpers with the same name in different files would silently map to one body. The scan must detect duplicate command names across files and error.
   - **Escaping paths (new):** copying breaks relative `use` paths that leave the module directory (`use ../shared.nu` resolves relative to the file, so in the copy it points outside). The scan should resolve local `use` targets and error if any falls outside the module dir — a detectable error, not just a documented limitation.

3. **One-shot dump.** A single `nu -n -c 'use <copy> *; ...'` call (glob import is required — without it commands are namespaced as `<mod> <cmd>` and `view source <cmd>` can't find them). Enumerate names with `scope modules | where name == <mod> | get commands` (verified) — it lists exactly the module's exports, while `scope commands | where type == custom` also picks up ambient commands (`banner`, `pwd`). For each name run `view source`, return a `name -> source` record as nuon. One process instead of one per command.
   - **`view source` fidelity (verified):** it strips both the `export` keyword and attributes (`@example` etc.). So every body already comes out as plain `def` — no de-export step needed — and attributes are lost in the output (acceptable for an embedded file; note it in docs). If export status is needed, take it from the step-2 AST scan.
   - **`main` (verified):** name the temp copy directory after the original module. Then `main` is exposed under the module name and `view source <module-name>` returns `def <module-name> [...]` — already renamed, matching the `module-commands-code-to-record` convention.

4. **Cascade.** From the target command, BFS over the record: find calls in each body (AST tokens intersected with record names), add reachable ones. This overlaps `dependencies` — reuse its call-detection helpers instead of reimplementing. A visited set is required: self-recursion is legal, so self-cycles exist (mutual recursion between top-level defs cannot parse, so other cycles don't).

5. **Assemble the file.** Reachable set in topological order — dependencies before dependents (the parser needs `def` before the call; an order always exists because the source parsed). Bodies are emitted as `view source` returned them (plain `def`). Decide whether the target command gets `export def` so the file also works as a module.

## Requirements

- [x] Signature: `<command> <module_path> <command_name> [--allow-export-env]`; `module_path` accepts a directory or a single `.nu` file (single-file modules exist)
- [x] `export-env` anywhere in the module without the flag → error with file list, no import happens
- [x] Local `use` target resolving outside the module directory → error
- [x] Duplicate command names across module files (after export-ification) → error
- [x] Output file is self-contained: `nu -n` parses it without errors, the target command is callable
- [x] Private dependencies (`def` without `export`) are extracted and land in the output as plain `def`
- [x] Definition order is topological; no duplicates
- [x] Tests: simple cascade; submodule via `export use`; private helper imported via plain `use` (the verified gap); refusal on `export-env`; pass with `--allow-export-env`; refusal on duplicate names

## Implementation plan

- [x] Step 1: safety scan — AST over all module `.nu` files: collect `export-env` (error/flag), local `use` targets (error if outside module dir), and all top-level command names (error on duplicates; record original export status)
- [x] Step 2: temp copy named after the module, rewrite top-level `def` → `export def` and top-level local `use` → `export use` in all `.nu` files
- [x] Step 3: one `nu -n -c` call — `use <copy> *`, enumerate via `scope modules`, `view source` each, output nuon record `name -> source`
- [x] Step 4: cascade — extract calls from each body (AST tokens ∩ record names), BFS with visited set; reuse `dependencies` helpers
- [x] Step 5: toposort, assemble text, reproduce external `use` lines (e.g. `std`), `--output` / stdout
- [x] Step 6: tests in `tests/test_commands.nu`: fixture module with a submodule, a private helper behind plain `use`, and a duplicate-name variant; fixture with `export-env`
- [x] Step 7: decide on `mod.nu` export (public command or internal at first)

## Affected files

- Existing files: `dotnu/commands.nu`, `dotnu/mod.nu`, `tests/test_commands.nu`
- New files: fixtures in `tests/assets/`

## Open questions

- Command name: `extract-command-code-runtime`? `embed-command`?
- Should the target command be `export def` in the output, so the file works both as a script source and as a module?
- Commands from external imported modules (e.g. `std`): reproduced as `use` lines in the output — is "resolves outside the module dir" the right definition of external?

## Execution result

**Date:** 2026-07-02

**Created files:**
- `tests/assets/module-embed/` (mod.nu, helpers.nu, pub.nu) — fixture: submodule via `export use`, private helper behind plain `use`, private def, `std` import, `main`
- `tests/assets/module-with-env/mod.nu` — fixture with `export-env`
- `tests/assets/module-dup/` (mod.nu, a.nu, b.nu) — fixture with the same private name in two files

**Modified files:**
- `dotnu/commands.nu` — `extract-module-command` plus helpers `module-files`, `scan-module-file`, `export-ify-file`, `dump-module-commands`
- `dotnu/mod.nu` — exported publicly
- `tests/test_commands.nu` — 7 tests covering all requirement scenarios
- `README.md`, `CLAUDE.md` — documentation
- `tests/output-yaml/coverage-untested.nuon` — coverage snapshot (public API 14 → 15)

**Summary:**
Implemented as planned, all 92 tests pass. Open questions resolved: name `extract-module-command`; original export status is restored in the output (private deps stay plain `def`), so the file works both sourced and as a module; external imports are any `use` whose target doesn't resolve to a local path — they are reproduced as `use` lines. One deviation: `where exported` (bare boolean column) is written as `where exported == true` because topiary's grammar can't parse the bare form.
