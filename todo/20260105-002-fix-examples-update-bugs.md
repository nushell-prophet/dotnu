# Fix identified bugs in examples-update

## Goal
Fix specific reliability issues found in `examples-update` command.

## Bugs identified

### 1. Duplicate result line bug (HIGH)
- Location: commands.nu:249
- Issue: `str replace` only replaces first occurrence
- If an example has multiple `--result` annotations, only the first gets updated
- Fix: Use `str replace --all` or handle multiple results explicitly

### 2. Potential crash in find-examples (MEDIUM)
- Location: commands.nu:274
- Issue: `| last` on potentially empty input crashes
- Scenario: Malformed @example with no block
- Fix: Add empty check before `| last`

### 3. Silent error corruption (MEDIUM)
- When example execution fails, error message replaces result
- This can corrupt the source file with error text
- Fix: Better error handling, possibly skip failed examples

### 4. Module name stripping fragile (LOW)
- Location: commands.nu:244
- Hard-coded module name removal may fail for nested modules
- Fix: More robust module prefix detection

## Tasks
- [ ] Write test cases that reproduce each bug
- [ ] Fix duplicate result line bug
- [ ] Fix empty input crash in find-examples
- [ ] Improve error handling for failed examples
- [ ] Review and fix module name stripping logic
- [ ] Add regression tests

## Related files
- `dotnu/commands.nu` - examples-update at lines 220-260
- `dotnu/commands.nu` - find-examples at lines 262-286
- `dotnu/commands.nu` - execute-example at lines 288-322
