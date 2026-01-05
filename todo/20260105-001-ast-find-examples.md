# Use ast-complete to improve find-examples

## Goal
Rewrite `find-examples` to use AST-based parsing instead of regex for more reliable @example detection.

## Background
The current `find-examples` uses regex patterns which can have false positives (e.g., `@example` inside strings). The new `ast-complete` command provides complete byte coverage and proper token classification.

## Tasks
- [ ] Analyze current `find-examples` implementation (commands.nu:262-286)
- [ ] Design AST-based approach using `ast-complete`
- [ ] Implement new `find-examples` using AST parsing
- [ ] Handle edge cases: @example in strings, comments, multiline blocks
- [ ] Test with existing module files in tests/assets/
- [ ] Update `examples-update` if interface changes

## Related files
- `dotnu/commands.nu` - find-examples at lines 262-286
- `dotnu/commands.nu` - ast-complete at lines 887-990
- `tests/ast-cases/attribute-detection.nu` - documents @example parsing behavior
