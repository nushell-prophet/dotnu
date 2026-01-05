# Add unit tests for examples-update

## Goal
Create comprehensive unit tests for `examples-update` and related commands.

## Current state
- `examples-update` has no unit tests in `test_commands.nu`
- Related functions `find-examples` and `execute-example` also untested
- Only integration testing via actual file updates

## Test cases needed

### find-examples
- [ ] Basic @example detection
- [ ] Multiple @examples in one file
- [ ] @example inside string (should NOT match)
- [ ] @example in comment (should NOT match)
- [ ] @example with --result flag
- [ ] @example without --result flag
- [ ] Malformed @example (missing block)
- [ ] Empty file input

### execute-example
- [ ] Simple expression execution
- [ ] Command with module context
- [ ] Error handling (invalid code)
- [ ] Multiline result output
- [ ] Result with special characters

### examples-update
- [ ] Single example update
- [ ] Multiple examples in file
- [ ] No changes needed (result matches)
- [ ] Error in example execution
- [ ] Dry-run behavior (if applicable)

## Tasks
- [ ] Create test fixtures in tests/assets/
- [ ] Write tests for find-examples
- [ ] Write tests for execute-example
- [ ] Write tests for examples-update
- [ ] Ensure tests run in CI

## Related files
- `tests/test_commands.nu` - add tests here
- `tests/assets/` - test fixtures
- `dotnu/commands.nu` - implementation
