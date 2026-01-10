# Add unit tests for examples-update

## Status: COMPLETED (2026-01-05)

## Goal
Create comprehensive unit tests for `examples-update` and related commands.

## Implementation
Commit: 2662ff5

Added 13 new unit tests (total now 56):

### find-examples (7 tests)
- [x] Basic @example detection
- [x] Multiple @examples in one file
- [x] @example inside string (should NOT match)
- [x] @example without --result flag (skipped)
- [x] Malformed @example (missing block)
- [x] Empty file input
- [x] Multiline code extraction

### execute-example (3 tests)
- [x] Simple expression execution
- [x] Error handling (returns error record)
- [x] Multiline result output

### examples-update (3 tests)
- [x] Single example update
- [x] Multiple examples in file
- [x] Preserves file when no examples

## Tasks
- [x] Write tests for find-examples
- [x] Write tests for execute-example
- [x] Write tests for examples-update
- [x] Ensure tests run in CI (verified with `nu toolkit.nu test-unit`)

## Related files
- `tests/test_commands.nu` - tests added at lines 513-670
- `dotnu/commands.nu` - implementation
