---
session: a5ec874c-0bf4-4b86-82a7-e2824b08673c
---

# Second audit of dotnu/commands.nu — terminal usability, reliability, code reduction

Second pass (2026-07-02). The first audit (git 5705623) is fully resolved; nothing below repeats it. Items marked **[verified]** were reproduced live in this session; §2.1 was measured. Order: verified bugs, measured perf, code reduction, terminal-experience choices, minor.

## 1. verified bugs

### 1.1 [verified] `list-module-exports` returns `--env` instead of the command name

`list-module-exports dotnu/commands.nu` includes `--env` and misses `embed-add` — the tool fails on its own codebase. Cause: after an `export def` token, `extract-exported-commands` takes the very next token as the name (`commands.nu:1304`), but for `export def --env foo` the next token is the flag. Fix: skip tokens whose content starts with `--` (covers `--env` and `--wrapped`) before taking the name.

### 1.2 [verified] `find-examples` silently drops any @example containing nested braces

`"@example 'x' { [1 2] | each { $in + 1 } } --result [2 3]" | find-examples` → `[]`. Closure and block braces both tokenize as `shape_block`, so `close_brace = block_tokens | get 1` (`commands.nu:705`) picks the *inner* opening brace; `--result` is then not found after it and the example is skipped. So `examples-update` silently never updates examples that use `each {}`, `if {}`, `match {}` — extremely common Nushell code. All 14 current examples in commands.nu happen to be brace-free, so the bug is latent here but hits any real module. Fix: find the closing brace by depth-counting `shape_block` tokens — the same starts-with/ends-with reduce the `--result` matcher already uses 20 lines below (`commands.nu:728-738`); extract it into one bracket-matching helper used by both.

### 1.3 [verified] `normalize-newlines` checks the platform, not the content

`commands.nu:858-861` only strips CRLF when the *host* is Windows. But a CRLF file can sit on any OS (git autocrlf, Windows-authored files, mounted volumes). Verified on Linux: CRLF input passes through untouched, and `"let a = 1\r\n\r\nlet b = 2" | split row --regex "\n+\n"` yields **1** block — so `set-x` on a CRLF file produces one giant block; `$`-anchored regexes like `$capture_point` are also at risk. Fix is a reduction: drop the OS branch, always `str replace --all "\r\n" "\n"` — a no-op on LF files, correct everywhere.

### 1.4 [verified] `list-module-interface`: prefix match on `main` has false positives

A file with `export def main-helper` and `def mainly` lists both as interface commands. Cause: `where $it starts-with 'main'` (`commands.nu:419`). Fix: `where $it == 'main' or $it starts-with 'main '`.

### 1.5 [verified] `variable-definitions-to-record`: greedy regex breaks on values containing `' = '`

`"let $sep = ' = '" | variable-definitions-to-record` errors — the greedy `let \$?(?<var>.*) =` (`commands.nu:892`) captures `sep = '` as the variable name. Practical impact: a var saved in a `--output` scaffold whose *value* contains `" = "` makes every re-extraction fail. Fix: `let \$?(?<var>\S+) =` (var names never contain spaces).

### 1.6 `filter-commands-with-no-tests`: substring `'test'` swallows `latest`

`'get-latest' =~ 'test'` is true — verified. Any command with `latest` (or `attest`, `contest`) in its name is silently treated as a test command (`commands.nu:74`): it disappears from the untested report AND everything it calls counts as covered. Fix: require a word boundary, e.g. `caller =~ '(^|[-_])test'`, mirroring the file pattern.

### 1.7 `embeds-update` on a failing script blames dotnu, not the script

`"nonexistent-cmd | print $in" | embeds-update --echo` dies with "External command had a non-zero exit code" pointing at `commands.nu:1246` — dotnu's own internals. The script's real error only appears on passthrough stderr. Fix: check the exit code and `error make` naming the user's script, like `run-expand-pipeline` (`commands.nu:638-644`) already does. Tradeoff to note in the code: `complete` buffers stderr, so a long-running script loses live progress output.

## 2. measured perf

### 2.1 `list-module-commands` attributes a caller to every token, then throws most away

On commands.nu: `dependencies` takes 3.2s, of which ~2.9s is the attribution loop (`commands.nu:1018-1038`) — it runs the per-token def-range lookup over all **8697** tokens (whitespace and gaps included), then filters down to the **933** call-shaped ones (`:1040`) and drops most of those as builtins (`:1041`). `ast-complete` itself is 0.11s; `help commands` 8ms. Both filters commute with the attribution (they read only `shape`/`content`), so move `where shape in [...]` and `where content not-in $excluded` *before* the `each` — after excluding builtins only a handful of tokens need the lookup. Expect the flagship `dependencies` to go from seconds to sub-second on real modules; no semantic change (attribute-block tokens are still dropped afterwards via `caller !~ '^@'`).

## 3. code reduction

- **`module-commands-code-to-record` has no callers** — repo-wide grep across the whole workspace finds only its own tests, README section, and the mod.nu export. Options: delete it (command + 3 tests + README + mod.nu line, ~45 lines — but it's public API, your call), or keep the name and shrink the body to a thin wrapper over `scan-module-file | where kind == 'def'`, removing the third copy of the def-header scan.
- **Dead parameter**: `extract-command-name` declares `module_path?: path` (`commands.nu:921`) that the body never reads; all four call sites are pipe-only. Delete it.
- **Double normalize**: `embeds-update` normalizes (`commands.nu:435`) and then `embeds-remove` normalizes again (`:1264`). Drop the outer call.
- **Duplicated def-rendering snippet** in `extract-module-command`: the `$sources | where name == $name | get 0.source | if exported {'export ' + $in}` block appears twice (`commands.nu:311-317` and `:340-345`). Hoist into one closure used by both paths.
- **Flag default in signature**: `set-x --regex: string = "\n+\n"` removes the `let regex = $regex | default ...` line (`commands.nu:100`).
- **Bare `nu` vs `$nu.current-exe`**: three child processes spawn bare `nu` from PATH (`commands.nu:325`, `:910`, `:1178`) while three others carefully use `^$nu.current-exe` (`:638`, `:798`, `:1246`). A different nu on PATH silently version-skews extraction results. Unify on `$nu.current-exe`.

## 4. terminal-experience choices

### 4.1 status messages go to stdout

`set-x` prints "the file … is produced. Source it" with plain `print` (`commands.nu:123`) — status on stdout. The terminal convention: stdout is for data, stderr for messages, so pipes stay clean (`examples-update` already gets this right with `print --stderr`). Move the hint to stderr; then `--quiet`, which exists only to mute this one line, can be deleted. Note: verified `commandline edit --replace` silently no-ops in non-interactive nu, so the hint is the only signal in scripts — keep it, just on stderr.

### 4.2 the `--echo` family is inconsistent, and `examples-update` can't read stdin

Four commands use `--echo` for "stdout instead of file". The bigger inconsistency: `embeds-update` and `expand-code` accept piped input (pipe in → result out, good filter behavior), while sibling `examples-update` demands a file path — the only one of the trio that can't sit in a pipe. Also subtle: `embeds-update` with *both* piped input and a file arg uses the file only as cd context and returns the result without saving (`commands.nu:473`) — surprising; either document it or make that combination save. The `--echo` name itself is nonstandard (the common idioms are default-to-stdout + `--in-place`, or `--write`), but in-place update is genuinely the primary workflow here, so renaming is optional polish — consistency across the trio is the real item.

### 4.3 `embed-add`: `--dry-run` shows nothing; `--published` is the flag that shows

`--dry-run` without `--published` writes nothing and returns just the piped input back (`commands.nu:845-846`) — you can't see what *would* be appended, which is the whole point of a dry run. And `--published` is a naming head-scratcher for "echo the embed representation". Merge them: `--dry-run` = don't save + return the representation; drop `--published`. (The sticky `--capture-path` env config and history-based capture, by contrast, are good terminal design — no change.)

### 4.4 family naming breaks tab-completion discovery

Public API mixes `embeds-update`/`embeds-remove` (plural) with `embed-add` (singular): typing `dotnu embeds-<TAB>` does not reveal `embed-add`. Prefix-discoverability is the terminal way to expose a command family. Align on one prefix (and decide whether `expand-code`, which is documented as the inverse of `embeds-update`, belongs in the family as e.g. `embeds-expand`). Breaking rename — batch with a version bump, your call.

## 5. minor

- `--script_path` (`commands.nu:1214`) is the last snake_case flag — rename `--script-path`.
- `capture-marker`: `if not $close { A } else { B }` (`commands.nu:1274`) — un-invert.
- `classify-gap` (`commands.nu:1392`) is the file's only non-exported def, against the stated all-exported convention.
- Help-text typo "result page" in `dependencies` and `list-module-commands` (`commands.nu:23`, `:971`).
- `comment-hash-colon` writes `# =>` — the name describes a prefix it no longer uses; rename (e.g. `comment-arrow`).
- `embeds-update` signature lists `string -> nothing` (`commands.nu:427`), an unreachable combination — piped input never saves.
- `find-capture-points` returns a `line` column no caller reads (`embeds-update` uses only `index` and the count) — return bare indices, or keep for debugging.

## Suggested order

1. §1.3 normalize-newlines (one-line fix, also a reduction)
2. §1.1, 1.4, 1.5, 1.6 — small verified fixes, one test each
3. §2.1 filter reorder (dependencies goes from seconds to sub-second)
4. §1.2 bracket-depth helper shared with the --result matcher
5. §3 deletions and dedup
6. §1.7, §4.1-4.3 message/flag polish
7. §4.4 and the `module-commands-code-to-record` deletion need your API decision
