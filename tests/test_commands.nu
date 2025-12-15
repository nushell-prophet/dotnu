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
