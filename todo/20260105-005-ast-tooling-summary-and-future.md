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

### 0. Document `ast --json` Output with Test Cases

**First step**: Create test cases in `tests/ast-cases/` using dotnu's literate programming to document `ast --json` behavior, similar to what we did for `ast --flatten`:

```
tests/ast-cases/
├── attribute-detection.nu    # @example, @test detection
├── block-boundaries.nu       # shape_block vs shape_closure
├── semicolon-stripping.nu    # gaps in ast --flatten
├── ast-complete.nu           # gap-filling behavior
└── ast-json-*.nu             # NEW: document ast --json output
```

**Test cases to create for `ast --json`**:
- `ast-json-basic.nu` - simple expressions, pipelines
- `ast-json-commands.nu` - command calls with args, flags
- `ast-json-blocks.nu` - blocks, closures, control flow
- `ast-json-spans.nu` - how span IDs map to byte positions

These serve dual purpose:
1. **Documentation** - understand the hierarchical structure
2. **Regression tests** - detect if Nushell changes AST format

Pattern to follow (from existing tests):
```nu
# --- Simple pipeline ---
'ls | where size > 1mb' | print $in
# => ls | where size > 1mb

ast --json 'ls | where size > 1mb' | to nuon | print $in
# => {block: [...], ...}
```

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

**Key Finding: `ast --json` is ideal for this use case**

Unlike dependency tracking (where `ast --flatten` is better because it shows calls inside closures), parsing individual commands for history extraction benefits from `ast --json`'s structured output:

```nu
# Complex case: subexpression as positional arg + flag
ast --json 'ls ("~" | path join smth) --all' | get block | from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
# => [
#   {Positional: {expr: {Subexpression: 337}, span: {...}, ty: Any}},
#   {Named: [{item: all, span: {...}}, null, null]}
# ]
```

**Advantages over `ast --flatten` for history parsing:**

| Feature | `ast --json` | `ast --flatten` |
|---------|-------------|-----------------|
| Arg type discrimination | `Positional` vs `Named` explicit | Must infer from position |
| Type information | `ty: Glob`, `ty: String`, `ty: Record` | `shape_*` less semantic |
| Complex expressions | Spans allow extraction | Tokens are flat, hard to group |
| Named param values | `[flag_name, null, value_expr]` | Must match `--flag` to next token |
| Nested expressions | Preserved as subexpression IDs | Flattened, loses structure |

**Example outputs:**

```nu
# open file.txt --raw
arguments: [
  {Positional: {expr: {GlobPattern: ["file.txt", false]}, ty: Glob}},
  {Named: [{item: raw}, null, null]}  # flag without value
]

# http get https://api.com --headers {Accept: json}
arguments: [
  {Positional: {expr: {String: "https://api.com"}, ty: String}},
  {Named: [{item: headers}, null, {expr: {Record: ...}, ty: Record}]}  # flag with value
]

# str replace foo bar --all
arguments: [
  {Positional: {expr: {String: foo}, ty: String}},
  {Positional: {expr: {String: bar}, ty: String}},
  {Named: [{item: all}, null, null]}
]
```

**Mapping to database schema:**
- `flag` → Named args where value is null
- `parameter_name` + `parameter_value` → Named args with value
- `positional_arg` + `arg_position` → Positional args (enumerate for position)
- `arg_type` → Use `ty` field directly

**Requirements**:
- Handle all valid Nushell syntax ✓ (AST handles this)
- Extract semantic meaning (which arg goes to which parameter) ✓ (Positional/Named explicit)
- Work on thousands of history entries efficiently (needs benchmarking)

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
