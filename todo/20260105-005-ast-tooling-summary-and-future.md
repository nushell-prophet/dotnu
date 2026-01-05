# AST Tooling: Summary and Future Work

## Summary of Work Done

### The Problem
Nushell's `ast --flatten` omits certain syntax elements:
- Semicolons (`;`)
- Assignment operators (`=`)
- Pipe operators (`|`)
- The `@` prefix for attributes
- Whitespace between tokens

This makes byte-position calculations unreliable and attribute detection require manual byte-checking.

### Solution: `ast-complete`

Created `ast-complete` command that fills gaps in `ast --flatten` output with synthetic tokens:

| Shape | Content |
|-------|---------|
| `shape_semicolon` | `;` |
| `shape_assignment` | `=` (with surrounding whitespace) |
| `shape_pipe` | `\|` |
| `shape_newline` | `\n` |
| `shape_whitespace` | spaces between tokens |
| `shape_gap` | unclassified (including `@` prefix) |

**Key property**: Every byte is accounted for - complete coverage from byte 0 to end.

### Built on top of `ast-complete`

#### `split-statements`
Splits source code into individual statements using AST analysis:
- Uses `shape_semicolon` and `shape_newline` as boundaries
- Tracks block depth to handle multi-line blocks correctly
- Returns `{statement, start, end}` table with byte positions

#### Refactored commands
- **`find-examples`**: Uses `ast-complete` to detect `@example` attributes via `shape_gap` ending with `@`
- **`list-module-commands`**: Uses `split-statements` for def detection + `ast-complete` for attribute detection

### Why `ast --flatten`?

We chose `ast --flatten` for its simplicity:
- Flat token list with `{content, shape, span}`
- Easy to process with standard nushell pipelines
- Spans provide byte positions for extraction

## Future Work

### 1. General-purpose `ast --json` Parser

`ast --json` provides the full AST with rich semantic information in a hierarchical structure:
- Expression types (Call, Pipeline, Block, etc.)
- Operator precedence
- Full syntactic context

**Challenges**:
- Complex nested hierarchy
- Spans are dynamic numbers requiring lookup
- Harder to query than flat structure

**Goal**: Create utilities to make `ast --json` accessible:
- Flatten hierarchy while preserving semantic info
- Resolve span numbers to byte positions
- Query helpers for common patterns

### 2. Pipeline Analysis Tool

Use case: Determine if a pipeline can have `print $in` or `save file.json` appended.

Questions to answer via AST:
- Does the pipeline produce output? (vs. `let` assignment, `if` without else, etc.)
- Is there already a sink at the end? (`save`, `print`, assignment)
- What's the expected output type?

This enables:
- Auto-capture of results in literate programming
- Smart script instrumentation
- REPL enhancements

### 3. History Command Parser (for nushell-history-based-completions)

Parse Nushell command history to extract:
- Command name
- Flags (`--verbose`, `-a`)
- Named parameters and their values (`--output file.txt`)
- Positional arguments with positions
- Argument types (path, int, string, etc.)

**Requirements**:
- Handle all valid Nushell syntax
- Extract semantic meaning (which arg goes to which parameter)
- Work on thousands of history entries efficiently

**Use in history-based-completions**:
- Build SQLite database of argument usage
- Enable cross-command value suggestions (paths used anywhere suggested everywhere)
- Type-aware completions (suggest paths where paths expected)

## Architecture Consideration

```
                    ast --flatten          ast --json
                         │                      │
                         ▼                      ▼
                   ┌─────────┐           ┌─────────────┐
                   │ast-complete│         │ast-json-parse│
                   └─────────┘           └─────────────┘
                         │                      │
          ┌──────────────┼──────────────┐      │
          ▼              ▼              ▼      ▼
    ┌──────────┐  ┌────────────┐  ┌─────────────────┐
    │split-    │  │find-       │  │pipeline-        │
    │statements│  │attributes  │  │analyzer         │
    └──────────┘  └────────────┘  └─────────────────┘
                                         │
                                         ▼
                                  ┌─────────────────┐
                                  │history-command- │
                                  │parser           │
                                  └─────────────────┘
```

## Commits from this session

```
01b6c1b refactor: use ast-complete for attribute detection in list-module-commands
300b40d refactor: use split-statements in list-module-commands for better scope detection
73d5ff7 feat: add split-statements command built on ast-complete
962e7d0 refactor: use ast-complete in find-examples for simpler attribute detection
```
