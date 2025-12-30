# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**dotnu** is a toolkit for Nushell module developers providing:
- **Literate programming**: Embed real command output in scripts as `# =>` annotations
- **Dependency analysis**: Analyze call chains between commands using AST parsing
- **Script profiling**: Measure execution timing of script blocks with `set-x`

## Commands

```bash
# Run all tests (unit + integration)
nu toolkit.nu test

# Run unit tests only (uses nutest framework)
nu toolkit.nu test-unit

# Run integration tests only
nu toolkit.nu test-integration

# Release (bumps version in nupm.nuon and README.md, commits, tags, pushes)
nu toolkit.nu release           # patch bump
nu toolkit.nu release --minor   # minor bump
nu toolkit.nu release --major   # major bump
```

## Architecture

### Module Structure

```
dotnu/
├── mod.nu          # Public API exports (13 commands)
└── commands.nu     # All implementation (~800 lines)
```

**mod.nu** exports these public commands:
- `dependencies` - Analyze command call chains
- `extract-command-code` - Extract command with its dependencies
- `filter-commands-with-no-tests` - Find untested commands
- `list-exported-commands` - List module's exported commands
- `embeds-*` / `embed-add` - Literate programming tools
- `set-x` / `generate-numd` - Script profiling

### Key Implementation Details

**AST-based attribute detection** (`commands.nu:499-508`): Uses `nu --ide-ast` to detect `@test`, `@example` decorators accurately, preventing false positives from `@something` inside strings.

**Dependency tracking algorithm**:
1. Line-based parsing finds `def` statements with byte offsets
2. AST parsing identifies attribute decorators
3. Range-based lookup associates calls with defining scopes
4. `generate` streams recursive dependency chains

### Test Structure

```
tests/
├── test_commands.nu    # Unit tests (~250 cases, nutest framework)
├── assets/             # Test fixtures
│   ├── b/              # Module dependency examples
│   └── module-say/     # Real-world module example
└── output-yaml/        # Integration test outputs
```

Unit tests use `@test` decorator and `assert` from `std/testing`.

## Dependencies

- **nutest**: Testing framework (cloned in CI from https://github.com/vyadh/nutest.git)
- **numd**: Optional, for markdown integration
- **std library**: Uses `std/iter` (scan) and `std/testing` (assert)

## Conventions

- Public commands: kebab-case, exported in mod.nu
- Internal helpers: kebab-case, not exported
- Test detection: commands named `test*` or in `test*.nu` files
- Documentation: `@example` decorators with `--result` for expected output
