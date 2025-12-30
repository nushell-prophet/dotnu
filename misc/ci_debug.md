# Windows CI Debug Investigation

## Problem
Windows CI hangs indefinitely on `nu toolkit.nu test --json`

## Environment
- Runner: `windows-latest`
- Nushell: latest (`hustcer/setup-nu@v3`)
- nutest: cloned from `https://github.com/vyadh/nutest.git`

## Timeline of fixes attempted

### 1. Git clone hang (FIXED)
**Symptom:** CI stuck on `git clone https://github.com/vyadh/nutest.git`
**Cause:** PowerShell triggers Windows Credential Manager prompts
**Fix:** Added `shell: bash` to the step

### 2. Test command hang (FIXED)
**Symptom:** CI stuck on `nu toolkit.nu test --json`
**Cause:** Same PowerShell issue
**Fix:** Added `shell: bash` to all CI steps

### 3. nutest run-tests hang (CURRENT)
**Symptom:** Hangs after `nutest run-tests --path tests/ --match-suites 'test_commands'`
**Debug output shows:**
```
DEBUG: starting tests
DEBUG: starting unit tests
DEBUG: importing nutest
DEBUG: nutest imported
DEBUG: calling nutest run-tests with display=nothing
[hangs here]
```

## Key observation
**nutest works on numd's Windows CI but hangs on dotnu's**

This suggests the issue is specific to dotnu's tests, not nutest itself.

## Differences between dotnu and numd

### 1. `to text` usage
- **dotnu:** Uses `to text` 14 times in `commands.nu`
- **numd:** Unknown, but nutest itself doesn't use `to text`
- **Concern:** `to text` produces `\r\n` on Windows, could cause CRLF issues

### 2. Test file differences
- **dotnu:** `tests/test_commands.nu` (~250 test cases)
- **numd:** Different test structure

### 3. Module imports
dotnu's `toolkit.nu` line 1-2:
```nushell
use ('dotnu' | path join 'commands.nu') *
use dotnu
```
This imports `commands.nu` which has heavy `to text` usage.

## CRLF fix attempted
Changed in `commands.nu`:
- Line 720: Added `str replace 'to text' "str join \"\\n\""` for serialized closure
- Line 730: Changed `| to text` → `| str join "\n"`

This fix ensures subprocess scripts use `\n` line endings, but **did not resolve the hang**.

## Hypotheses to investigate

### H1: Test file parsing issue
Something in `tests/test_commands.nu` causes nutest to hang during discovery/parsing on Windows.

### H2: Module loading issue
The `use ('dotnu' | path join 'commands.nu') *` dynamic path might behave differently on Windows.

### H3: Specific test hangs
One of the 46 unit tests might hang when executed on Windows (subprocess, file path, etc.)

## Key finding: nutest subprocess discovery

nutest's `discover.nu` (line 57) spawns a subprocess to discover tests:
```nushell
let result = (^$nu.current-exe --no-config-file --commands $query)
```

Where `$query` is:
```nushell
source ($file); scope commands | where ...
```

When this sources `tests/test_commands.nu`, it imports `../dotnu/commands.nu *`.

**The hang likely occurs during:**
1. Subprocess spawn on Windows
2. Or parsing/loading `commands.nu` in that subprocess
3. Or `par-each` (line 43) parallel discovery

## Next steps

1. **Add debug to test file:** Add `print -e` at top of `test_commands.nu` to see if source completes
2. **Try single-threaded:** Check if nutest has option to disable `par-each`
3. **Simplify test file:** Create minimal test file to isolate issue
4. **Compare with numd:** numd's commands.nu (707 lines) vs dotnu (766 lines)

## Files involved
- `.github/workflows/ci.yml` - CI configuration
- `toolkit.nu` - Test runner entry point
- `dotnu/commands.nu` - Main implementation (uses `to text`)
- `tests/test_commands.nu` - Unit tests
