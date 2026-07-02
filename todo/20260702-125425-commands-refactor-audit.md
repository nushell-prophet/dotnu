---
session: 9b061696-a884-40ff-a2d6-dd91aa2cb639
---

# Refactoring audit of dotnu/commands.nu — reliability, logic, code reduction

Full-file audit (2026-07-02). Items marked **[verified]** were reproduced live during the audit; the rest are read from the code. Order: embeds group first, then other verified bugs, then code reduction, then minor.

## 1. embeds group (priority)

### 1.1 [verified] `embeds-update` rewrites unrelated blank lines — replace the string-splice with an index-based splice

`"let a = 1\n\n\n\nlet b = 2\n" | embeds-update --echo` collapses the four blank lines to one. Cause: the final `str replace --all --regex '\n{3,}' "\n\n"` (`commands.nu:438`) runs over the whole script, not just around capture points.

The squash exists only to clean up after the fragile string-replacement splice (`commands.nu:430-439`), which also needs two other hacks: the `# to-not-be-replaced-again` marker for duplicate lines and the prepended `"\n"` anchor for a capture point on line 1.

Fix: rebuild by line index instead. `find-capture-points` already scans `lines`; make it return `lines | enumerate | where ...` (index + line). Then `embeds-update` walks the enumerated script lines and appends each result right after its capture index — exact insertion, no markers, no anchor hack, no squash. All three hacks and their comments go away (~10 lines less, and the blank-line corruption is fixed as a side effect).

### 1.2 [verified] silent misalignment: results are zipped onto capture points without a count check

Repro: a capture point inside a `def` that is called twice. The def's line gets its own first output, and the *unrelated* top-level capture line gets the def's second output; the real output of that line is dropped. No error, wrong annotations written.

`execute-and-parse-results` even documents this limit in a comment (`commands.nu:1341-1344`), but `zip` (`commands.nu:426`) silently truncates to the shorter list. Fail-fast fix: after execution, `if ($results | length) != ($points | length) { error make ... }` with a message naming the likely cause (capture point inside a def, or executed in a loop). Cheap, and turns silent corruption into a clear error.

### 1.3 make the capture-point invariant structural, not documented

The `$capture_point` const comment (`commands.nu:7-11`) warns that `find-capture-points` and `execute-and-parse-results` must agree or outputs misalign. With 1.1's enumerated table, pass the *indices* into `execute-and-parse-results` and replace lines by index there (instead of re-matching the regex per line, `commands.nu:1327-1333`). Then only one function ever scans for capture points, and the invariant can't break by construction.

### 1.4 drop the `view source` closure metaprogramming in `execute-and-parse-results`

`commands.nu:1310-1324` builds the injected `embed-in-script` def from a closure via `view source` plus an order-sensitive chain of single-occurrence `str replace` calls (`capture-marker --close` must be replaced before `capture-marker`). `comment-hash-colon` carries a `--source-code` dual mode and an inner closure (`commands.nu:1285-1303`) just to support this inlining.

Verified simpler path: `view source <def-name>` works on plain defs and drops `@example` attributes. So: (a) simplify `comment-hash-colon` to a plain one-pipeline def (no flag, no closure); (b) prepend `view source comment-hash-colon` verbatim into the generated script; (c) write the `embed-in-script` def as a plain interpolated string with the markers baked in. Removes the whole replace chain and the dual-mode flag (~15 lines, and no more dependence on `view source` closure formatting).

### 1.5 single const for the `# => ` prefix

The annotation prefix is hardcoded twice and must agree: `comment-hash-colon` writes it (`commands.nu:1290`), `embeds-remove` strips it (`commands.nu:1357`). Hoist to a const next to `$capture_point`, for the same reason that const exists.

### 1.6 `embed-add` polish

- `--dry_run` (`commands.nu:793`) is the only snake_case flag in the codebase — rename to `--dry-run`.
- Stray `#todo: --` in the signature (`commands.nu:794`).
- The strip regex `'(?s)\| ?dotnu embed-add.*$'` (`commands.nu:804`) assumes the command is invoked as `dotnu embed-add`; with `use dotnu/commands.nu *` the bare `embed-add` call is not stripped and lands in the capture file. Make the `dotnu ` prefix optional in the regex.

### 1.7 `get-command-from-hist` prints instead of failing

On non-sqlite history it `print`s a message and returns nothing (`commands.nu:855-856`); the caller then dies on `get previous` with a confusing error far from the cause. Fail-fast: `error make` there.

## 2. examples group

### 2.1 [verified] `examples-update` silently skips multi-line `--result` values

`"} --result [a\nb]" | str replace --regex '\} --result .+$' 'X'` does not match (`.` doesn't cross newlines, no `(?s)`), so the replace at `commands.nu:484` no-ops. `find-examples` deliberately supports multi-line results (the bracket-depth matcher, `commands.nu:676-693`), so the two halves disagree. Fix: `'(?s)\} --result .+$'`, plus a test with a multi-line result fixture.

### 2.2 dead `result_line` field in `find-examples`

`commands.nu:701` says "not used, kept for interface compatibility" — but the only caller (`examples-update`) reads just `original` and `code`. Remove the field, its type signature entry, and the `result_line: ""` plumbing in both branches (~8 lines).

### 2.3 `execute-example` error channel is shape-sniffing

It returns either a string or `{error: string}`, and the caller dispatches on `describe == "record<error: string>"` (`commands.nu:462`) — breaks the moment the record gains a field. Either `error make` inside and `try`/`catch` in the caller, or return a uniform `{ok: bool, ...}` record.

### 2.4 attribute detection is duplicated

The window-2 "shape_gap ends with `@`" pattern lives in `find-examples` (`commands.nu:629-638`) and again in `list-module-commands` (`commands.nu:996-1005`). Extract one helper (e.g. `find-attribute-tokens []: table -> table` over `ast-complete` output) used by both.

## 3. parsing infrastructure

### 3.1 [verified] `split-statements`: braces inside comments corrupt depth tracking

`"# {\nlet a = 1\nlet b = 2" | split-statements` returns ONE statement — the `{` in the comment bumps the depth counter and everything after merges. Cause: comments are bundled into `shape_gap` tokens and `commands.nu:1530-1534` counts `{`/`}` in raw gap content.

This is upstream of `dependencies`, `scan-module-file` (so `extract-module-command`) and `module-commands-code-to-record` — a module with a `{` in a top-level comment gets wrong statement boundaries everywhere. Fix: strip comment tails inside gap content before counting — per line of the gap, drop everything from `#` on (strings have their own shapes and never land in gaps, so `#` in a gap is always a comment). Add the repro above as a test.

## 4. extract-command-code group

### 4.1 unquoted `source` paths break on spaces

`commands.nu:167` (`$'source ($module_path)'`) and `commands.nu:1276` (`$"source ($file)..."`) emit unquoted paths; a path with a space produces a broken script. The template inside `dummy_closure` already quotes it (`commands.nu:1268`) — make the other two match.

### 4.2 duplicated "no command found" check — one side is dead

`dummy-command`'s generated script errors when the command is missing (`commands.nu:1235`), and `extract-command-code` re-checks via `$extracted_command.1? == null` (`commands.nu:147`). Determine which path actually fires when `nu -n -c` fails inside the pipeline and keep exactly one check (fail-fast at the source).

### 4.3 `variable-definitions-to-record` swallows failures

`commands.nu:913-915` returns `{}` on any non-zero exit — a broken vars header in a previously extracted file silently loses the user's saved variables instead of reporting the parse failure.

### 4.4 strategic question: two extractors

`extract-command-code` (+ `dummy-command`, ~120 lines of view-source templating) and `extract-module-command` (runtime, newer) overlap heavily. If the vars-preservation / `--set-vars` workflow migrated onto the runtime extractor, the whole `dummy-command` machinery could retire. Big reduction, but it changes a public command's behavior — needs a decision, not a drive-by.

~~## 5. dead code [verified by repo-wide grep]~~ done

- `check-clean-working-tree` (`commands.nu:859-879`): no production caller, only its own test. Its error text offers a `--no-git-check` flag that exists nowhere — leftover from a removed feature. Delete command + test (~30 lines).
- `format-substitutions` (`commands.nu:1191-1207`): no production caller, only its own test. Delete command + test (~25 lines).

## 6. minor

- `list-module-exports` / `list-module-interface` end with `print 'No command found'` and return nothing (`commands.nu:380-383`, `commands.nu:399-402`) — a `nothing -> list<string>` command that sometimes prints breaks composition. Return the empty list; let interactive callers print.
- `dependencies` re-runs `help commands` once per file via `list-module-commands` (`commands.nu:1023`); could be computed once per `dependencies` call and passed down. Only matters on many-file modules.
- `nu-completion-command-name` hardcodes `' extract-command-code '` in its context regex (`commands.nu:963`) — attaching it to any other command's parameter silently misparses.
- Stale in-code todo at `commands.nu:405` (`# todo: make configuration like --autocommit in file itself`) — implement or move here.

## Suggested order

1. ~~§5 dead code (pure deletion, zero risk)~~ done
2. §3.1 split-statements comment fix (verified bug, affects most commands)
3. §1.1–1.3 embeds-update splice rewrite + count assert (verified bugs, one coherent change)
4. §2.1–2.2 examples-update regex + dead field
5. §1.4–1.7, §2.3–2.4, §4.1–4.3 as small follow-ups
6. §4.4 only after a decision
