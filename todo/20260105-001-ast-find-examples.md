# Use ast-complete to improve find-examples

## Status: COMPLETED (2026-01-05)

## Goal
Rewrite `find-examples` to use AST-based parsing instead of regex for more reliable @example detection.

## Background
The current `find-examples` uses regex patterns which can have false positives (e.g., `@example` inside strings). The new `ast-complete` command provides complete byte coverage and proper token classification.

## Tasks
- [x] Analyze current `find-examples` implementation (commands.nu:262-286)
- [x] Design AST-based approach using `ast-complete`
- [x] Implement new `find-examples` using AST parsing
- [x] Handle edge cases: @example in strings, comments, multiline blocks
- [x] Test with existing module files in tests/assets/
- [x] Update `examples-update` if interface changes (no changes needed)

## Implementation
Commit: 6808e50

The new implementation:
- Uses `ast --flatten | flatten span` to tokenize source with byte positions
- Detects @example by checking if byte at (start-1) is "@"
- Extracts code from shape_block token boundaries
- Handles --result flag via shape_flag tokens
- Returns empty list for malformed or missing examples (no crash)

## Related files
- `dotnu/commands.nu` - find-examples at lines 266-351
- `dotnu/commands.nu` - ast-complete at lines 893-968
- `tests/ast-cases/attribute-detection.nu` - documents @example parsing behavior
