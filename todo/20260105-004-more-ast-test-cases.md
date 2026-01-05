# Add more AST behavior test cases

## Status: COMPLETED (2026-01-05)

## Goal
Document additional AST parsing behaviors to ensure `ast-complete` and AST-based parsing remain robust across Nushell versions.

## Implementation
Commit: 7f4491b

Added three new test case files (572 lines total):

### string-literals.nu
- [x] Single vs double quotes (shape_string)
- [x] Interpolated strings (shape_string_interpolation with nested tokens)
- [x] Raw strings (shape_raw_string)
- [x] Backtick strings (shape_external)
- [x] Multiline strings
- [x] Empty strings

### operators.nu
- [x] Arithmetic operators (+, -, *, /, **) - shape_operator
- [x] Comparison operators (==, !=, <) - shape_operator
- [x] Logical operators (and, or, not) - shape_operator
- [x] Range operators (.., ..<) - shape_operator
- [x] Pipeline operator (|) - shape_pipe (NOT stripped!)
- [x] ast-complete whitespace filling demo

### variables.nu
- [x] Variable declaration (let, mut) - shape_internalcall + shape_vardecl
- [x] Variable reference ($x) - shape_garbage (undefined) or shape_variable
- [x] Environment variables ($env.X) - shape_variable + shape_string
- [x] Special variables ($in, $nu) - shape_variable
- [x] Type annotations
- [x] Variable shadowing

## Existing test cases (from previous work)
- `tests/ast-cases/semicolon-stripping.nu` - `;` and `=` stripping
- `tests/ast-cases/block-boundaries.nu` - shape_block vs shape_closure
- `tests/ast-cases/attribute-detection.nu` - @example, @test parsing
- `tests/ast-cases/def-parsing.nu` - def/export def tokenization
- `tests/ast-cases/ast-complete.nu` - gap-filling verification

## Future work (not implemented)
- Complex structures (nested closures, match, try/catch, loops)
- Edge cases (unicode, long lines, deep nesting)

## Related files
- `tests/ast-cases/` - test case directory (now 8 files)
- `dotnu/commands.nu` - ast-complete command
