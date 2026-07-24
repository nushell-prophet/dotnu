use std/assert
use std/testing *

# Each test here re-runs an `@example` block from dotnu/commands.nu and checks it still
# produces its recorded `--result` — the promise the README makes to a reader.
#
# The example code runs in a fresh `nu -n` child that imports only the public API — the
# same way `execute-example` records the results, so what is checked here is what a
# reader of the README would actually get.
def run-example [code: string]: nothing -> any {
    let result = ^$nu.current-exe -n -c $"use dotnu/\n($code) | to nuon" | complete
    assert equal $result.exit_code 0 $"example failed:\n($result.stderr)"
    $result.stdout | from nuon
}

# Analyze command dependencies in a module
@test
def "dotnu dependencies example 1" [] {
    let actual = run-example 'dotnu dependencies ...(glob tests/assets/module-say/say/*.nu) | sort-by caller callee'
    let expected = [{caller: question filename_of_caller: "ask.nu" callee: null step: 0} {caller: hello filename_of_caller: "hello.nu" callee: null step: 0} {caller: say callee: hello filename_of_caller: "mod.nu" step: 0} {caller: say callee: hi filename_of_caller: "mod.nu" step: 0} {caller: say callee: question filename_of_caller: "mod.nu" step: 0} {caller: hi filename_of_caller: "mod.nu" callee: null step: 0} {caller: test-hi callee: hi filename_of_caller: "test-hi.nu" step: 0}] | sort-by caller callee
    assert equal $actual $expected
}

# Find commands not covered by tests
@test
def "dotnu filter-commands-with-no-tests example 1" [] {
    let actual = run-example 'dotnu dependencies ...(glob tests/assets/module-say/say/*.nu) | dotnu filter-commands-with-no-tests | sort-by caller'
    let expected = [[caller filename_of_caller]; [question "ask.nu"] [hello "hello.nu"] [say "mod.nu"]] | sort-by caller
    assert equal $actual $expected
}

# Generate script with timing instrumentation
@test
def "dotnu set-x example 1" [] {
    let actual = run-example 'dotnu set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text'
    let expected = 'mut $prev_ts = ( date now )
print ("> sleep 0.5sec" | nu-highlight)
sleep 0.5sec
'
    assert equal $actual $expected
}
