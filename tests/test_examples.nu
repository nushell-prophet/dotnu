use std/assert
use std/testing *

# Analyze command dependencies in a module
@test
def "dotnu dependencies example 1" [] {
    let actual = (dotnu dependencies ...(glob tests/assets/module-say/say/*.nu))
    let expected = [{caller: hello, filename_of_caller: "hello.nu", callee: null, step: 0}, {caller: question, filename_of_caller: "ask.nu", callee: null, step: 0}, {caller: say, callee: hello, filename_of_caller: "mod.nu", step: 0}, {caller: say, callee: hi, filename_of_caller: "mod.nu", step: 0}, {caller: say, callee: question, filename_of_caller: "mod.nu", step: 0}, {caller: hi, filename_of_caller: "mod.nu", callee: null, step: 0}, {caller: test-hi, callee: hi, filename_of_caller: "test-hi.nu", step: 0}]
    assert equal $actual $expected
}

# Find commands not covered by tests
@test
def "dotnu filter-commands-with-no-tests example 1" [] {
    let actual = (dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests)
    let expected = [[caller, filename_of_caller]; [hello, "hello.nu"], [question, "ask.nu"], [say, "mod.nu"]]
    assert equal $actual $expected
}

# Generate script with timing instrumentation
@test
def "dotnu set-x example 1" [] {
    let actual = (set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text)
    let expected = "mut $prev_ts = ( date now )
print (\"> sleep 0.5sec\" | nu-highlight)
sleep 0.5sec
"
    assert equal $actual $expected
}