# Fix identified bugs in examples-update

## Status: COMPLETED (2026-01-05)

## Goal
Fix specific reliability issues found in `examples-update` command.

## Bugs identified

### 1. Duplicate result line bug (HIGH)
- Location: commands.nu:249
- Issue: `str replace` only replaces first occurrence
- If an example has multiple `--result` annotations, only the first gets updated
- Fix: Use `str replace --all` or handle multiple results explicitly

### 2. Potential crash in find-examples (MEDIUM) - FIXED
- Location: commands.nu:274
- Issue: `| last` on potentially empty input crashes
- Scenario: Malformed @example with no block
- Fix: Add empty check before `| last`
- **RESOLVED**: Fixed in commit 6808e50 (AST rewrite of find-examples)

### 3. Silent error corruption (MEDIUM)
- When example execution fails, error message replaces result
- This can corrupt the source file with error text
- Fix: Better error handling, possibly skip failed examples

### 4. Module name stripping fragile (LOW)
- Location: commands.nu:244
- Hard-coded module name removal may fail for nested modules
- Fix: More robust module prefix detection

## Tasks
- [x] Write test cases that reproduce each bug (tested manually)
- [x] Fix duplicate result line bug
- [x] Fix empty input crash in find-examples (fixed in option 1)
- [x] Improve error handling for failed examples
- [x] Review and fix module name stripping logic (verified working)
- [ ] Add regression tests (deferred to option 3)

## Implementation
Commit: faac906

Changes:
- Use full `original` text for matching instead of just result line
- Use `do -i` with `complete` to capture subprocess errors properly
- Skip failed examples with warning to stderr instead of corrupting file
- Module name stripping logic verified working correctly

## Related files
- `dotnu/commands.nu` - examples-update at lines 224-268
- `dotnu/commands.nu` - find-examples at lines 270-361
- `dotnu/commands.nu` - execute-example at lines 363-390
