# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**dotnu** is a toolkit for Nushell module developers providing:
- **Literate programming**: Embed real command output in scripts as `# =>` annotations
- **Dependency analysis**: Analyze call chains between commands using AST parsing
- **Script profiling**: Measure execution timing of script blocks with `set-x`

## Commands

```bash
# Run all tests - ALWAYS use this command for testing
nu toolkit.nu test

# Update integration test fixtures when output changes
nu toolkit.nu test --update

# Release (bumps version in nupm.nuon and README.md, commits, tags, pushes)
nu toolkit.nu release           # patch bump
nu toolkit.nu release --minor   # minor bump
nu toolkit.nu release --major   # major bump
```

**Important**: Always use `nu toolkit.nu test` (not `test-unit` or `test-integration` separately).
The combined command provides proper test output and summary.

**Output mode is auto-detected.** On a terminal you get the human view — only the non-passing tests (with the assertion on failure), then a `N passed, M failed` summary.
Piped or redirected (agents, CI) you get machine-readable JSON.
This uses `is-terminal --stdout`, not `$nu.is-interactive` (which is false for any `nu toolkit.nu ...` script run, so it can't tell agent from human).
Force with `--json` / `--pretty`; `--all` also lists passing tests.
JSON rows are `{type, name, status: 'passed'|'failed'|'changed', file, message}` — `message` holds the assertion text on failure.
The JSON channel always carries every row; the failures-only trim is human-view only.

```bash
# Check test coverage - requires both source AND test files
nu -c 'use dotnu/; ["dotnu/*.nu" "tests/test_commands.nu" "toolkit.nu"] | each { glob $in } | flatten | dotnu dependencies ...$in | dotnu filter-commands-with-no-tests'
```

## Architecture

### Module Structure

```
dotnu/
├── mod.nu          # Public API exports (selective)
└── commands.nu     # All implementation (all commands exported)
```

**Export convention**: All commands in `commands.nu` are exported by default (for internal use, testing, and development).
The public API is managed through `mod.nu`, which selectively re-exports only the user-facing commands.
To add a command to the public API, add it to the list in `mod.nu`.

**Imports**:
- `use dotnu/` - import public API commands
- `use dotnu/commands.nu *` - import all commands (including internal)

**mod.nu** exports these public commands:
- `dependencies` - Analyze command call chains
- `diagnose` - Resolve `nu --ide-check` diagnostics to line numbers, source lines and the flagged text
- `examples-update` - Run `@example` blocks and refresh their `--result` values
- `expand-code` - Generate code lines from `#**` directive comments (the inverse of `embeds-update`)
- `extract-module-command` - Extract command with its dependency cascade from a module into one self-contained script (runtime, via `view source`); `--vars`/`--set-vars` emit a debug scaffold with the target's parameters as editable `let` bindings and its body unwrapped
- `filter-commands-with-no-tests` - Find untested commands
- `list-module-exports` - List all exported definitions (export def + export use)
- `list-module-interface` - List module's callable interface (main commands)
- `module-commands-code-to-record` - Extract every command of a module as a `{command_name: source_code}` record
- `embeds-*` / `embed-add` - Literate programming tools
- `set-x` / `generate-numd` - Script profiling

### Key Implementation Details

**AST-based attribute detection** (`find-attribute-tokens`): Uses the `ast --flatten` token stream (via `ast-complete`) to detect `@test`, `@example` decorators accurately, preventing false positives from `@something` inside strings.

**Dependency tracking algorithm**:
1. `split-statements` (built on `ast-complete`) finds `def` statements with byte ranges
2. AST parsing identifies attribute decorators
3. Range-based lookup associates calls with defining scopes
4. `generate` streams recursive dependency chains

### Test Structure

```
tests/
├── test_commands.nu    # Unit tests (nutest framework)
├── test_examples.nu    # Unit tests that execute the `@example` blocks
├── assets/             # Test fixtures
│   ├── b/              # Module dependency examples
│   └── module-say/     # Real-world module example
├── ast-cases/          # Embed scripts documenting AST behavior (not run by the suite)
└── output-yaml/        # Integration test snapshots (yaml and nuon)
```

Unit tests use `@test` decorator.
Integration tests compare command output against fixture files.

## Dependencies

- **nutest**: Testing framework (cloned in CI from https://github.com/vyadh/nutest.git)
- **numd**: Optional, for markdown integration
- **std library**: Tests use `std/assert` (assert) and `std/testing` (the `@test` attribute)

## Conventions

- **Naming**: All commands use kebab-case
- **Exports**: All commands in `commands.nu` are exported; `mod.nu` controls public API
- **Internal commands**: Exported from `commands.nu` but not listed in `mod.nu`
- **Test detection**: Command name contains `test`, or the file matches `test*.nu`
- **Documentation**: `@example` decorators with `--result` for expected output
