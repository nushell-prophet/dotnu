---
task-name: fix list-module-exports handling of export use main / bare export use
status: draft
created: 2026-06-11
updated: 2026-06-11
---

# `list-module-exports`: wrong name for submodule `main`, bare `export use` dropped

## Problem

Two related defects in `extract-exported-commands` + `replace-main-with-module-name`
(found during live testing for todo/20260611-2057-test-dotnu-agent-commands.md,
Nushell 0.113.1, 7763f51, against nu-goodies):

1. `export use sub.nu [main]` — the literal item `main` is replaced with
   the **parent** module name (from `$path`), not the submodule name.
   For nu-goodies this yields `nu-goodies` twice (from `gradient-screen.nu`
   and `cprint.nu` mains) instead of `gradient-screen` and `cprint`.
2. `export use file.nu` without an item list is ignored entirely —
   `update-public-git` (whole-file re-export, its `main` becomes the
   `update-public-git` command) is missing from the output.

## Repro

```nu
use dotnu/ *
list-module-exports ~/repos/nu-goodies/nu-goodies/mod.nu
# contains "nu-goodies" twice; lacks gradient-screen, cprint, update-public-git
nu -n -c 'use ~/repos/nu-goodies/nu-goodies *; scope commands | where type == custom | get name'
# ground truth (minus std-lib custom commands banner/pwd)
```

## Fix direction

In the `export use` branch of `extract-exported-commands` the module-path
token is already at hand (`$idx + 1`): map `main` items to that file's
stem instead of deferring to `replace-main-with-module-name`, and when no
list follows, emit the file stem (its `main`). Note a bare `export use`
also re-exports the file's other exports — full fidelity needs reading
the referenced file; decide how deep to go.
