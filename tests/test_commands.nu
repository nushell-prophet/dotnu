use std assert
use std/testing *

# Import all functions from commands.nu (including internals not re-exported via mod.nu)
use ../dotnu/commands.nu *

# =============================================================================
# Tests for escape-for-quotes
# =============================================================================

@test
def "escape-for-quotes handles double quotes" [] {
    let result = 'abcd"dfdaf" "' | escape-for-quotes

    assert equal $result 'abcd\"dfdaf\" \"'
}

@test
def "escape-for-quotes handles backslashes" [] {
    let result = 'path\to\file' | escape-for-quotes

    assert equal $result 'path\\to\\file'
}

@test
def "escape-for-quotes handles plain text" [] {
    let result = 'hello world' | escape-for-quotes

    assert equal $result 'hello world'
}

# =============================================================================
# Tests for extract-command-name
# =============================================================================

@test
def "extract-command-name handles export def" [] {
    let result = 'export def --env "test" --wrapped' | extract-command-name

    assert equal $result 'test'
}

@test
def "extract-command-name handles simple def" [] {
    let result = 'def "my-command" []' | extract-command-name

    assert equal $result 'my-command'
}

@test
def "extract-command-name handles def with flags" [] {
    let result = 'export def --env my-command [' | extract-command-name

    assert equal $result 'my-command'
}

# =============================================================================
# Tests for variable-definitions-to-record
# =============================================================================

@test
def "variable-definitions-to-record parses simple let" [] {
    let result = "let $quiet = false; let no_timestamp = false" | variable-definitions-to-record

    assert equal $result {quiet: false no_timestamp: false}
}

@test
def "variable-definitions-to-record handles multiline" [] {
    let result = "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record

    assert equal $result {a: b c: d}
}

@test
def "variable-definitions-to-record handles null" [] {
    let result = "let $a = null" | variable-definitions-to-record

    assert equal $result {a: null}
}

# =============================================================================
# Tests for comment-hash-colon
# =============================================================================

@test
def "comment-hash-colon formats table output" [] {
    let result = [[a]; [b]] | table | comment-hash-colon

    assert ($result | str starts-with '# => ')
    assert ($result =~ 'a')
    assert ($result =~ 'b')
}

@test
def "comment-hash-colon handles string" [] {
    let result = "hello" | comment-hash-colon

    assert equal $result '# => hello'
}

# =============================================================================
# Tests for embeds-remove
# =============================================================================

@test
def "embeds-remove removes annotation lines" [] {
    let input = "command | print $in\n# => output line 1\n# => output line 2\nnext command"
    let result = $input | embeds-remove

    assert ($result !~ '# =>')
    assert ($result =~ 'command')
    assert ($result =~ 'next command')
}

@test
def "embeds-remove preserves regular comments" [] {
    let input = "# regular comment\ncommand"
    let result = $input | embeds-remove

    assert ($result =~ '# regular comment')
}

# =============================================================================
# Tests for find-capture-points
# =============================================================================

@test
def "find-capture-points finds print $in lines" [] {
    let input = "ls | print $in\necho hello\nget data | print $in"
    let result = $input | find-capture-points

    assert equal ($result | length) 2
    assert ($result.0 =~ 'ls')
    assert ($result.1 =~ 'get data')
}

@test
def "find-capture-points ignores commented lines" [] {
    let input = "# ls | print $in\necho hello | print $in"
    let result = $input | find-capture-points

    assert equal ($result | length) 1
    assert ($result.0 =~ 'echo hello')
}

# =============================================================================
# Tests for join-next
# =============================================================================

@test
def "join-next merges caller-callee relationships" [] {
    let data = [[caller callee step filename_of_caller]; [a b 0 test] [b c 0 test]]
    let result = $data | join-next $data

    assert equal ($result | length) 1
    assert equal $result.0.caller 'a'
    assert equal $result.0.callee 'c'
    assert equal $result.0.step 1
}

# =============================================================================
# Tests for list-module-commands
# =============================================================================

@test
def "list-module-commands extracts command relationships" [] {
    let result = list-module-commands tests/assets/b/example-mod1.nu

    assert (($result | length) > 0)
    assert ('caller' in ($result | columns))
    assert ('callee' in ($result | columns))
    assert ('filename_of_caller' in ($result | columns))
}

@test
def "list-module-commands definitions-only mode" [] {
    let result = list-module-commands --definitions-only tests/assets/b/example-mod1.nu

    assert (($result | length) > 0)
    assert ('caller' in ($result | columns))
    assert ('filename_of_caller' in ($result | columns))
}

# =============================================================================
# Tests for dependencies
# =============================================================================

@test
def "dependencies returns table with expected columns" [] {
    let result = glob tests/assets/b/*.nu | dependencies ...$in

    assert ('caller' in ($result | columns))
    assert ('callee' in ($result | columns))
    assert ('filename_of_caller' in ($result | columns))
    assert ('step' in ($result | columns))
}

@test
def "dependencies handles module-say example" [] {
    let result = dependencies ...(glob tests/assets/module-say/say/*.nu)

    # Should find the 'say' command that calls 'hello', 'hi', and 'question'
    let say_calls = $result | where caller == 'say'
    assert (($say_calls | length) > 0)
}

@test
def "dependencies handles files with @example containing same-file calls" [] {
    # This tests the fix for infinite loop when @example blocks call commands defined in the same file
    let result = dependencies dotnu/commands.nu

    # Should complete without hanging and have no self-references
    let self_refs = $result | where caller == callee
    assert (($self_refs | length) == 0) "should have no self-referential calls"
}

@test
def "dependencies excludes calls inside attribute blocks" [] {
    let result = list-module-commands tests/assets/attribute-edge-cases.nu

    # @example should not appear as a caller
    let attr_callers = $result | where caller =~ '^@'
    assert (($attr_callers | length) == 0) "no attribute decorators should appear as callers"

    # decorated-command should call email-formatter (the call inside the function body)
    let decorated_calls = $result | where caller == 'decorated-command'
    assert ('email-formatter' in $decorated_calls.callee) "decorated-command should call email-formatter"

    # The call inside @example block should NOT appear as a dependency
    # (only the call inside the actual function body should be tracked)
    let example_calls = $result | where caller == '@example'
    assert (($example_calls | length) == 0) "@example should not be a caller"
}

@test
def "dependencies ignores @something inside strings" [] {
    let result = list-module-commands tests/assets/attribute-edge-cases.nu

    # email-formatter should appear as a caller (it's a real command)
    assert ('email-formatter' in $result.caller) "email-formatter should be a caller"

    # main-command should call email-formatter
    let main_calls = $result | where caller == 'main-command'
    assert ('email-formatter' in $main_calls.callee) "main-command should call email-formatter"
}

# =============================================================================
# Tests for filter-commands-with-no-tests
# =============================================================================

@test
def "filter-commands-with-no-tests filters tested commands" [] {
    let result = dependencies ...(glob tests/assets/module-say/say/*.nu)
    | filter-commands-with-no-tests

    # 'hi' is covered by 'test-hi', so it should not appear
    assert ('hi' not-in $result.caller)

    # Commands without tests should remain
    assert (($result | length) > 0)
}

# =============================================================================
# Tests for generate-numd
# =============================================================================

@test
def "generate-numd wraps code in nu fences" [] {
    let result = "ls\necho hello" | generate-numd

    assert ($result =~ '```nu')
    assert ($result =~ 'ls')
}

@test
def "generate-numd handles multiple blocks" [] {
    let result = "block1\n\nblock2" | generate-numd

    # Should have two code blocks
    let fence_count = $result | split row '```nu' | length
    assert ($fence_count >= 2)
}

# =============================================================================
# Tests for set-x
# =============================================================================

@test
def "set-x transforms script with echo flag" [] {
    let result = set-x tests/assets/set-x-demo.nu --echo

    # Should prepend timestamp tracker
    assert ($result =~ 'mut \$prev_ts')
    # Should add print statement before each block
    assert ($result =~ 'print \("> sleep 0.5sec"')
    # Should preserve original commands
    assert ($result =~ 'sleep 0.5sec')
    # Should add timing output
    assert ($result =~ 'ansi grey')
}

# =============================================================================
# Tests for extract-command-code
# =============================================================================

@test
def "extract-command-code extracts command with echo flag" [] {
    let result = extract-command-code tests/assets/b/example-mod1.nu lscustom --echo

    # Should include source statement for module (path separators vary by OS)
    assert ($result =~ 'source.*example-mod1\.nu')
    # Should include the command code
    assert ($result =~ 'ls')
}

@test
def "extract-command-code handles quoted command names" [] {
    let result = extract-command-code tests/assets/b/example-mod1.nu 'command-5' --echo

    # Path separators vary by OS
    assert ($result =~ 'source.*example-mod1\.nu')
    assert ($result =~ 'command-3')
}

# =============================================================================
# Tests for list-exported-commands
# =============================================================================

@test
def "list-exported-commands finds exported commands" [] {
    let result = list-exported-commands tests/assets/b/example-mod1.nu --export

    # Should find exported commands
    assert ('lscustom' in $result)
    assert ('command-5' in $result)
    # Should replace 'main' with module name
    assert ('example-mod1' in $result)
}

@test
def "list-exported-commands excludes non-exported when flag set" [] {
    let result = list-exported-commands tests/assets/b/example-mod1.nu --export

    # Private commands should not be in exported list
    assert ('sort-by-custom' not-in $result)
    assert ('command-3' not-in $result)
}

# =============================================================================
# Tests for embeds-update
# =============================================================================

@test
def "embeds-update updates embeds in piped script" [] {
    # Script needs newlines around capture points for replacement to work
    let script = "\n'hello' | str upcase | print $in\n"
    let result = $script | embeds-update

    # Should contain the original command
    assert ($result =~ 'str upcase')
    # Should contain the embedded output
    assert ($result =~ '# => HELLO')
}

@test
def "embeds-update preserves script structure" [] {
    let script = "# comment\n\n1 + 1 | print $in\n\n# another"
    let result = $script | embeds-update

    # Should preserve comments
    assert ($result =~ '# comment')
    assert ($result =~ '# another')
    # Should add result
    assert ($result =~ '# => 2')
}

# =============================================================================
# Tests for embed-add
# =============================================================================

# Note: embed-add requires shell history which isn't available in automated tests
# The command works by reading the current command from history, which can't be
# simulated in a test environment. Testing skipped.

# =============================================================================
# Tests for embeds-setup
# =============================================================================

@test
def "embeds-setup sets capture path in env" [] {
    # Test without --auto-commit to avoid git operations
    let test_path = ($nu.temp-path | path join 'test-capture.nu')
    embeds-setup $test_path

    assert equal $env.dotnu.embeds-capture-path $test_path
}

@test
def "embeds-setup adds .nu extension if missing" [] {
    let test_path = ($nu.temp-path | path join 'test-capture')
    embeds-setup $test_path

    assert ($env.dotnu.embeds-capture-path | str ends-with '.nu')
}

# =============================================================================
# Tests for execute-and-parse-results
# =============================================================================

@test
def "execute-and-parse-results captures output" [] {
    let script = "'test output' | print $in"
    let result = execute-and-parse-results $script

    assert (($result | length) == 1)
    assert ($result.0 =~ 'test output')
}

@test
def "execute-and-parse-results handles multiple capture points" [] {
    let script = "1 + 1 | print $in\n\n2 + 2 | print $in"
    let result = execute-and-parse-results $script

    assert (($result | length) == 2)
    assert ($result.0 =~ '2')
    assert ($result.1 =~ '4')
}

# =============================================================================
# Tests for module-commands-code-to-record
# =============================================================================

@test
def "module-commands-code-to-record extracts command code" [] {
    let result = module-commands-code-to-record tests/assets/b/example-mod1.nu

    # Should be a record
    assert (($result | describe) =~ 'record')
    # Should have command names as keys
    assert ('lscustom' in ($result | columns))
    # Command code should contain the body
    assert ($result.lscustom =~ 'ls')
}

@test
def "module-commands-code-to-record handles multiple commands" [] {
    let result = module-commands-code-to-record tests/assets/b/example-mod1.nu

    # Should extract multiple commands
    assert (($result | columns | length) > 1)
}

# =============================================================================
# Tests for helper functions
# =============================================================================

# Note: capture-marker is a private (non-exported) function used internally
# by the embeds system. It generates zero-width Unicode characters used as
# delimiters. Testing is done indirectly through embeds-update tests.

@test
def "check-clean-working-tree passes for unmodified files" [] {
    # This file should not be modified in git, so the check should pass
    # If modified, the test will catch regressions in git status parsing
    check-clean-working-tree tests/assets/b/example-mod1.nu

    # If we get here without error, the check passed
    assert true
}

@test
def "dummy-command generates executable code" [] {
    let result = dummy-command 'lscustom' tests/assets/b/example-mod1.nu '#END#'

    # Should be valid nushell code string
    assert (($result | describe) == 'string')
    # Should contain use/source statement
    assert (($result =~ 'use') or ($result =~ 'source'))
}

@test
def "format-substitutions formats example documentation" [] {
    let examples = [
        {annotation: "Example:" command: "ls" result: "files..."}
    ]
    let result = format-substitutions $examples "List files command"

    # Should include description
    assert ($result =~ 'List files command')
    # Should be formatted as comments
    assert ($result =~ '^# ')
}

@test
def "get-dotnu-capture-path returns valid path" [] {
    $env.dotnu = {embeds-capture-path: '/tmp/test.nu'}
    let result = get-dotnu-capture-path

    assert equal $result '/tmp/test.nu'
}

@test
def "nu-completion-command-name returns command list" [] {
    # Test with a simple module
    let result = nu-completion-command-name tests/assets/b/example-mod1.nu

    # Should return a list of commands
    assert (($result | describe) =~ 'list')
    assert ('lscustom' in $result)
}

# =============================================================================
# Tests for find-examples
# =============================================================================

@test
def "find-examples detects basic @example" [] {
    let input = '@example "test" { 1 + 1 } --result 2
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 1
    assert equal ($result | first | get code) "1 + 1"
}

@test
def "find-examples detects multiple @examples" [] {
    let input = '@example "first" { 1 } --result 1
def foo [] {}

@example "second" { 2 } --result 2
def bar [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 2
    assert equal ($result | get code) ["1" "2"]
}

@test
def "find-examples ignores @example inside string" [] {
    let input = 'let x = "has @example inside"
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 0
}

@test
def "find-examples skips @example without --result" [] {
    let input = '@example "no result" { 1 + 1 }
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 0
}

@test
def "find-examples handles empty input" [] {
    let result = '' | find-examples

    assert equal ($result | length) 0
}

@test
def "find-examples handles malformed @example" [] {
    # Missing block - only has the attribute name
    let input = '@example
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 0
}

@test
def "find-examples extracts multiline code" [] {
    let input = '@example "multiline" {
    let x = 1
    let y = 2
    $x + $y
} --result 3
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 1
    assert ($result | first | get code | str contains "let x = 1")
}

# =============================================================================
# Tests for execute-example
# =============================================================================

@test
def "execute-example runs simple expression" [] {
    # Create temp file for context
    let temp = '/tmp/test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    let result = execute-example '1 + 1' $temp

    assert equal $result '2'
}

@test
def "execute-example returns error record on failure" [] {
    let temp = '/tmp/test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    let result = execute-example 'nonexistent-command' $temp

    assert equal ($result | describe) 'record<error: string>'
}

@test
def "execute-example handles multiline result" [] {
    let temp = '/tmp/test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    let result = execute-example '[1, 2, 3]' $temp

    assert equal $result '[1, 2, 3]'
}

# =============================================================================
# Tests for examples-update
# =============================================================================

@test
def "examples-update updates result values" [] {
    let temp = '/tmp/test-examples-update.nu'
    '@example "add" { 1 + 1 } --result 0
export def dummy [] { 1 }' | save -f $temp

    let result = examples-update $temp --echo

    assert ($result | str contains '--result 2')
    assert not ($result | str contains '--result 0')
}

@test
def "examples-update handles multiple examples" [] {
    let temp = '/tmp/test-examples-update.nu'
    '@example "first" { 1 + 1 } --result 0
export def foo [] {}

@example "second" { 2 + 2 } --result 0
export def bar [] {}' | save -f $temp

    let result = examples-update $temp --echo

    assert ($result | str contains '--result 2')
    assert ($result | str contains '--result 4')
}

@test
def "examples-update preserves file when no examples" [] {
    let temp = '/tmp/test-examples-update.nu'
    let content = 'export def foo [] { 1 }'
    $content | save -f $temp

    let result = examples-update $temp --echo

    assert equal $result $content
}
