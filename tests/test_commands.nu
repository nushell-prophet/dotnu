use std/assert
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
    assert equal ($result | get index) [0 2]
    assert ($result.0.line =~ 'ls')
    assert ($result.1.line =~ 'get data')
}

@test
def "find-capture-points ignores commented lines" [] {
    let input = "# ls | print $in\necho hello | print $in"
    let result = $input | find-capture-points

    assert equal ($result | length) 1
    assert equal $result.0.index 1
    assert ($result.0.line =~ 'echo hello')
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

    # extract-exported-commands is genuinely recursive — the only self-reference
    # allowed; anything else would be a false edge from an @example block.
    # (`where caller == callee` compares against the string "callee" — use a closure)
    let self_refs = $result | where {|row| $row.caller == $row.callee }
    assert equal ($self_refs | get caller) ['extract-exported-commands']
}

@test
def "dependencies terminates on recursive commands" [] {
    # a recursive command makes a cycle in the call graph;
    # chain expansion must stop at the fixpoint instead of looping forever
    let result = dependencies tests/assets/recursive.nu

    let self_calls = $result | where {|row| $row.caller == $row.callee } | get caller
    assert equal $self_calls [countdown]
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

@test
def "filter-commands-with-no-tests rejects non-dependencies input" [] {
    # nothing, a scalar, and a wrong-shaped table all point back to `dotnu dependencies`
    let msgs = [
        (try { filter-commands-with-no-tests; '' } catch {|e| $e.msg })
        (try { "demo.nu" | filter-commands-with-no-tests; '' } catch {|e| $e.msg })
        (try { [[a b]; [1 2]] | filter-commands-with-no-tests; '' } catch {|e| $e.msg })
    ]
    for msg in $msgs { assert ($msg =~ 'dotnu dependencies') }
}

@test
def "filter-commands-with-no-tests passes an empty dependencies result through" [] {
    assert equal ([] | filter-commands-with-no-tests) []
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
# Tests for list-module-interface
# =============================================================================

@test
def "list-module-interface finds main command" [] {
    let result = list-module-interface tests/assets/b/example-mod1.nu

    assert equal $result ['main']
}

@test
def "list-module-interface returns empty list when no main" [] {
    let result = list-module-interface tests/assets/b/example-mod2.nu

    assert equal $result []
}

@test
def "list-module-interface strips main prefix from subcommands" [] {
    let temp = $nu.temp-dir | path join 'test-module-interface.nu'
    "export def main [] {}\nexport def 'main sub1' [] {}\nexport def 'main sub2' [] {}" | save -f $temp

    let result = list-module-interface $temp

    assert ('main' in $result)
    assert ('sub1' in $result)
    assert ('sub2' in $result)
}

# =============================================================================
# Tests for list-module-exports
# =============================================================================

@test
def "list-module-exports finds exported commands" [] {
    let result = list-module-exports tests/assets/b/example-mod1.nu

    # Should find exported commands
    assert ('lscustom' in $result)
    assert ('command-5' in $result)
    # Should replace 'main' with module name
    assert ('example-mod1' in $result)
}

@test
def "list-module-exports excludes non-exported" [] {
    let result = list-module-exports tests/assets/b/example-mod1.nu

    # Private commands should not be in exported list
    assert ('sort-by-custom' not-in $result)
    assert ('command-3' not-in $result)
}

# Fixture matches `scope commands` ground truth:
# nu -n -c 'use tests/assets/export-use *; scope commands | where type == custom | get name'
@test
def "list-module-exports resolves export use forms" [] {
    let result = list-module-exports tests/assets/export-use/mod.nu

    # `export use gradient.nu [main]` → submodule name, not parent module name
    assert ('gradient' in $result)
    assert ('unused' not-in $result)
    # bare `export use helpers.nu` → its main plus prefixed subcommands
    assert ('helpers' in $result)
    assert ('helpers clean' in $result)
    # `export use extra.nu *` → its main as stem, other exports unprefixed
    assert ('extra' in $result)
    assert ('shine' in $result)
    # own `export def main` still maps to the module name
    assert ('export-use' in $result)
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
def "embeds-update annotates a capture point on the first line" [] {
    # No leading newline before the capture point
    let script = "'hello' | str upcase | print $in\n"
    let result = $script | embeds-update

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

@test
def "embeds-update errors when a capture point runs more than once" [] {
    # capture point inside a def called twice -> 2 outputs for 1 point.
    # Fail-fast instead of silently zipping the extra output onto another line.
    let script = "def f [] {\n1 | print $in\n}\nf\nf\n"

    assert error { $script | embeds-update }
}

@test
def "embeds-update places annotations by source line, not execution order" [] {
    # b (defined 2nd) is called before a, so results come back in reverse source order.
    # A positional pairing would put b's output under a's line; tagging by source index keeps
    # them aligned.
    let script = "def a [] {
    \"AAA\" | print $in
}
def b [] {
    \"BBB\" | print $in
}
b
a
"
    let out = $script | embeds-update --echo | lines
    let a_idx = $out | enumerate | where item =~ 'AAA.*print' | get 0.index
    let b_idx = $out | enumerate | where item =~ 'BBB.*print' | get 0.index
    assert equal ($out | get ($a_idx + 1)) '# => AAA'
    assert equal ($out | get ($b_idx + 1)) '# => BBB'
}

# =============================================================================
# Tests for find-expand-directives
# =============================================================================

@test
def "find-expand-directives pairs a directive with its end marker" [] {
    let result = ("#** ls | to text\nfoo\n#**end" | lines) | find-expand-directives

    assert equal ($result | length) 1
    assert equal $result.0.start 0
    assert equal $result.0.end 2
    assert equal $result.0.pipeline 'ls | to text'
}

@test
def "find-expand-directives errors on an unclosed directive" [] {
    assert error { ("#** ls | to text\nfoo" | lines) | find-expand-directives }
}

@test
def "find-expand-directives errors on a stray end marker" [] {
    assert error { ("#**end" | lines) | find-expand-directives }
}

@test
def "find-expand-directives errors on an empty pipeline" [] {
    assert error { ("#**\n#**end" | lines) | find-expand-directives }
}

# =============================================================================
# Tests for expand-code
# =============================================================================

@test
def "expand-code fills a directive block with generated lines" [] {
    let script = "#** [a b c] | each { $\"open ($in)\" } | to text\n#**end"
    let result = $script | expand-code

    assert equal $result "#** [a b c] | each { $\"open ($in)\" } | to text\nopen a\nopen b\nopen c\n#**end\n"
}

@test
def "expand-code replaces stale generated lines and keeps surrounding code" [] {
    let script = "before\n#** [x y] | each { $\"z ($in)\" } | to text\nOLD\nMORE OLD\n#**end\nafter"
    let result = $script | expand-code

    assert equal $result "before\n#** [x y] | each { $\"z ($in)\" } | to text\nz x\nz y\n#**end\nafter\n"
}

@test
def "expand-code is idempotent on re-run" [] {
    let script = "#** [a b c] | each { $\"open ($in)\" } | to text\n#**end"

    assert equal ($script | expand-code) ($script | expand-code | expand-code)
}

@test
def "expand-code preserves blank lines the pipeline emits" [] {
    # `lines` drops only `to text`'s trailing newline, so a leading/trailing blank line stays.
    let script = "#** ['' mid ''] | to text\n#**end"
    let result = $script | expand-code

    assert equal $result "#** ['' mid ''] | to text\n\nmid\n\n#**end\n"
}

# =============================================================================
# Tests for embed-add
# =============================================================================

# Note: embed-add requires shell history which isn't available in automated tests
# The command works by reading the current command from history, which can't be
# simulated in a test environment. Testing skipped.

# =============================================================================
# Tests for execute-and-parse-results
# =============================================================================

@test
def "execute-and-parse-results captures output" [] {
    let script = "'test output' | print $in"
    let result = execute-and-parse-results $script ($script | find-capture-points | get index)

    assert (($result | length) == 1)
    assert ($result.0.capture =~ 'test output')
}

@test
def "execute-and-parse-results handles multiple capture points" [] {
    let script = "1 + 1 | print $in\n\n2 + 2 | print $in"
    let result = execute-and-parse-results $script ($script | find-capture-points | get index)

    assert (($result | length) == 2)
    # Each result is tagged with its source line index, so look up by identity, not position.
    assert (($result | where index == 0 | get 0.capture) =~ '2')
    assert (($result | where index == 2 | get 0.capture) =~ '4')
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

@test
def "module-commands-code-to-record handles lines before first def" [] {
    # module-say starts with `use` lines and comments before the first def;
    # the forward-fill must stay length-preserving or every row misaligns
    let result = module-commands-code-to-record tests/assets/module-say/say/mod.nu

    assert ($result.hi =~ 'export def hi')
    assert ($result.say =~ 'export def main')
}

# =============================================================================
# Tests for helper functions
# =============================================================================

# Note: capture-marker is a private (non-exported) function used internally
# by the embeds system. It generates zero-width Unicode characters used as
# delimiters. Testing is done indirectly through embeds-update tests.

@test
def "get-dotnu-capture-path returns valid path" [] {
    $env.dotnu = {embeds-capture-path: '/tmp/test.nu'}
    let result = get-dotnu-capture-path

    assert equal $result '/tmp/test.nu'
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

@test
def "find-examples parses list result values" [] {
    let input = "@example \"list\" { ['a' 'b'] } --result ['a' 'b']
def foo [] {}"

    let result = $input | find-examples

    assert equal ($result | length) 1
    # Verify the full list is captured, not just the opening bracket
    assert ($result | first | get original | str contains "['a' 'b']")
}

@test
def "find-examples captures multi-line list result" [] {
    # Genuinely multi-line list: opening/closing brackets bundle whitespace
    # ("[\n    " / "\n]"), so exact-string bracket matching truncated the value
    # at the opening bracket. This guards that regression.
    let input = '@example "multi" { [9 9] } --result [
    9
    9
]
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 1
    let result_value = $result | first | get original | split row "--result" | last
    # Full list captured: closing bracket present, not truncated at "["
    assert ($result_value | str trim | str ends-with "]")
    # Both list elements captured
    assert equal ($result_value | split row "9" | length) 3
}

@test
def "find-examples parses record result values" [] {
    let input = '@example "record" { {a: 1} } --result {a: 1}
def foo [] {}'

    let result = $input | find-examples

    assert equal ($result | length) 1
    assert ($result | first | get original | str contains "{a: 1}")
}

# =============================================================================
# Tests for execute-example
# =============================================================================

@test
def "execute-example runs simple expression" [] {
    # Create temp file for context
    let temp = $nu.temp-dir | path join 'test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    let result = execute-example '1 + 1' $temp

    assert equal $result '2'
}

@test
def "execute-example errors on failure" [] {
    let temp = $nu.temp-dir | path join 'test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    assert error { execute-example 'nonexistent-command' $temp }
}

@test
def "execute-example handles multiline result" [] {
    let temp = $nu.temp-dir | path join 'test-execute-example.nu'
    'export def dummy [] { 1 }' | save -f $temp

    let result = execute-example '[1, 2, 3]' $temp

    assert equal $result '[1, 2, 3]'
}

# =============================================================================
# Tests for examples-update
# =============================================================================

@test
def "examples-update updates result values" [] {
    let temp = $nu.temp-dir | path join 'test-examples-update-single.nu'
    '@example "add" { 1 + 1 } --result 0
export def dummy [] { 1 }' | save -f $temp

    let result = examples-update $temp --echo

    assert ($result | str contains '--result 2')
    assert not ($result | str contains '--result 0')
}

@test
def "examples-update handles multiple examples" [] {
    let temp = $nu.temp-dir | path join 'test-examples-update-multiple.nu'
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
    let temp = $nu.temp-dir | path join 'test-examples-update-none.nu'
    let content = 'export def foo [] { 1 }'
    $content | save -f $temp

    let result = examples-update $temp --echo

    assert equal $result $content
}

@test
def "examples-update preserves dollar signs in results" [] {
    # Test that $var references in result strings are not lost
    # (regression test for regex backreference bug)
    let temp = $nu.temp-dir | path join 'test-examples-dollar.nu'
    '@example "test" { "has $a variable" } --result "old"
export def dummy [] { 1 }' | save -f $temp

    let result = examples-update $temp --echo

    # The result should contain the $a, not have it stripped
    assert ($result | str contains '$a')
}

@test
def "examples-update replaces a multi-line result value" [] {
    # The stale result spans two lines; without `(?s)` the regex could not cross the
    # newline, so a multi-line result (e.g. the set-x example in commands.nu) was
    # silently skipped and left stale.
    let temp = $nu.temp-dir | path join 'test-examples-multiline.nu'
    "@example \"ml\" { 1 + 1 } --result 'line1
line2'
export def dummy [] { 1 }" | save -f $temp

    let result = examples-update $temp --echo

    assert ($result | str contains '--result 2')
    assert not ($result | str contains 'line2')
}

# split-statements tests

@test
def "split-statements splits on semicolons" [] {
    let result = 'let x = 1; let y = 2' | split-statements

    assert equal ($result | length) 2
    assert equal ($result | get statement) ['let x = 1' 'let y = 2']
}

@test
def "split-statements splits on newlines" [] {
    let result = "let a = 1\nlet b = 2" | split-statements

    assert equal ($result | length) 2
    assert equal ($result | get statement) ['let a = 1' 'let b = 2']
}

@test
def "split-statements preserves multi-line blocks" [] {
    let result = "def foo [] {\n  let x = 1\n  x\n}" | split-statements

    assert equal ($result | length) 1
    assert ($result.0.statement | str contains 'def foo')
    assert ($result.0.statement | str contains 'let x = 1')
}

@test
def "split-statements ignores braces inside comments" [] {
    # A `{` in a top-level comment must not bump the block-depth counter and merge
    # the statements that follow it into one.
    let result = "# {\nlet a = 1\nlet b = 2" | split-statements

    assert equal ($result | length) 2
    assert equal $result.1.statement 'let b = 2'
}

@test
def "split-statements splits after a trailing comment following a block" [] {
    # The newline after a trailing comment is bundled into a shape_gap (` # note }\n`)
    # that starts with a space, not a newline, so the boundary was missed and the next
    # statement merged into the block. The comment tail lives in the gap between the two
    # statements (like a standalone comment line), so it is not part of either statement.
    let result = "if true { 1 } # note }\nlet b = 2" | split-statements

    assert equal ($result | length) 2
    assert equal ($result | get statement) ['if true { 1 }' 'let b = 2']
}

@test
def "split-statements handles empty input" [] {
    let result = '' | split-statements

    assert equal ($result | length) 0
}

@test
def "split-statements provides byte positions" [] {
    let result = 'let x = 1; let y = 2' | split-statements

    assert equal $result.0.start 0
    assert equal $result.0.end 9
    assert equal $result.1.start 11
}

# =============================================================================
# Tests for extract-module-command
# =============================================================================

@test
def "extract-module-command embeds private deps in a runnable script" [] {
    let script = extract-module-command tests/assets/module-embed greet

    let run = nu -n -c ($script + "\ngreet") | complete
    assert equal ($run.stdout | str trim) 'hello world!'
    assert ($script =~ 'export def greet ') # originally exported commands stay exported
    assert ($script =~ '(?m)^def subject') # private deps stay private
    assert ($script =~ 'use std/assert') # external imports reproduced, not embedded
    assert ($script !~ 'shout') # unreachable commands are left out
}

@test
def "extract-module-command exposes main as the module name" [] {
    let script = extract-module-command tests/assets/module-embed main

    assert ($script =~ 'export def module-embed ')

    let run = nu -n -c ($script + "\nmodule-embed") | complete
    assert equal ($run.stdout | str trim) 'hello world!'
}

@test
def "extract-module-command follows export use into submodules" [] {
    let script = extract-module-command tests/assets/module-embed shout

    let run = nu -n -c ($script + "\nshout") | complete
    assert equal ($run.stdout | str trim) 'LOUD'
    assert ($script =~ '(?m)^def shout-suffix') # submodule's private dep embedded
}

@test
def "extract-module-command refuses modules with export-env" [] {
    let error_msg = try {
        extract-module-command tests/assets/module-with-env env-greet
        ''
    } catch {|err| $err.msg }

    assert ($error_msg =~ 'export-env')
    assert ($error_msg =~ 'mod.nu')
}

@test
def "extract-module-command passes with --allow-export-env" [] {
    let script = extract-module-command tests/assets/module-with-env env-greet --allow-export-env

    assert ($script !~ 'export-env') # env blocks are not carried into the output

    let run = nu -n -c ($script + "\nenv-greet") | complete
    assert equal ($run.stdout | str trim) 'hi'
}

@test
def "extract-module-command refuses duplicate names across files" [] {
    let error_msg = try {
        extract-module-command tests/assets/module-dup cmd-a
        ''
    } catch {|err| $err.msg }

    assert ($error_msg =~ 'helper')
    assert ($error_msg =~ 'a.nu')
    assert ($error_msg =~ 'b.nu')
}

@test
def "extract-module-command handles a single-file module" [] {
    let script = extract-module-command tests/assets/export-use/helpers.nu clean

    let run = nu -n -c ($script + "\nclean") | complete
    assert equal ($run.stdout | str trim) 'helpers clean'
}

@test
def "extract-module-command --vars scaffolds signature vars and unwraps the body" [] {
    let script = extract-module-command tests/assets/module-embed greet-loud --vars

    assert ($script =~ 'let \$upper = false') # switch parameter -> `let` binding defaulting to false
    assert ($script =~ '# def greet-loud') # target's def header is commented, body left live
    assert ($script !~ '(?m)^(export )?def greet-loud') # target is not emitted as a def
    assert ($script =~ '(?m)^def subject') # private dep still embedded
    assert ($script =~ 'export def greet-word') # exported dep still embedded

    # sourcing the scaffold runs the unwrapped body with the vars in scope
    let run = nu -n -c $script | complete
    assert equal ($run.stdout | str trim) 'hello world!'
}

@test
def "extract-module-command --set-vars overrides defaults and implies --vars" [] {
    let script = extract-module-command tests/assets/module-embed greet-loud --set-vars {upper: true}

    assert ($script =~ 'let \$upper = true')

    let run = nu -n -c $script | complete
    assert equal ($run.stdout | str trim) 'HELLO WORLD!'
}

@test
def "extract-module-command --vars preserves edited values on re-extraction" [] {
    let out = $nu.temp-dir | path join 'test-extract-vars-preserve.nu'
    extract-module-command tests/assets/module-embed greet-loud --vars --output $out

    # user edits a variable value in the saved file; re-extraction keeps the edit ...
    open $out | str replace 'let $upper = false' 'let $upper = true' | save --force $out
    extract-module-command tests/assets/module-embed greet-loud --vars --output $out
    assert (open $out | str contains 'let $upper = true')

    # ... unless --clear-vars resets it to the signature default
    extract-module-command tests/assets/module-embed greet-loud --vars --output $out --clear-vars
    assert (open $out | str contains 'let $upper = false')

    rm --force $out
}

# =============================================================================
# Public API smoke test
# =============================================================================

# Runs every mod.nu-exported command in a fresh `nu -n` child that imports only the
# public API (`use dotnu/`) — the way users load dotnu. The star import at the top of
# this file puts every internal command in this process's top-level scope, which masks
# bugs in runtime name lookups (e.g. `view source <string>` resolves against
# top-level-visible commands): such code passes every in-process test yet fails in a
# user's session. Smoke only — asserts each command runs; unit and snapshot tests own
# correctness.
@test
def "public api runs under prefixed import alone" [] {
    let example_fixture = $nu.temp-dir | path join 'test-public-api-smoke-example.nu'
    "@example 'add' { 1 + 1 } --result 2\nexport def dummy [] { 1 }" | save --force $example_fixture

    # One entry per mod.nu export; null = not runnable headless (embed-add reads the
    # interactive shell history)
    let snippets = {
        'dependencies': 'dotnu dependencies tests/assets/b/example-mod1.nu tests/assets/b/example-mod2.nu | ignore'
        'embed-add': null
        'embeds-remove': "'1 + 1' | dotnu embeds-remove | ignore"
        'embeds-update': "'1 + 1 | print $in' | dotnu embeds-update | ignore"
        'examples-update': $"dotnu examples-update ($example_fixture) --echo | ignore"
        'expand-code': "\"#** [1 2] | to text\n#**end\" | dotnu expand-code | ignore"
        'extract-module-command': 'dotnu extract-module-command tests/assets/module-embed greet-loud | ignore'
        'filter-commands-with-no-tests': 'dotnu dependencies tests/assets/b/example-mod1.nu | dotnu filter-commands-with-no-tests | ignore'
        'generate-numd': "'ls' | dotnu generate-numd | ignore"
        'list-module-exports': 'dotnu list-module-exports tests/assets/b/example-mod1.nu | ignore'
        'list-module-interface': 'dotnu list-module-interface tests/assets/b/example-mod1.nu | ignore'
        'module-commands-code-to-record': 'dotnu module-commands-code-to-record tests/assets/b/example-mod1.nu | ignore'
        'set-x': 'dotnu set-x tests/assets/set-x-demo.nu --echo --quiet | ignore'
    }

    # A command added to mod.nu without a smoke entry here fails loudly
    let public = open dotnu/mod.nu | parse --regex '"(?<name>[^"]+)"' | get name
    assert equal ($snippets | columns | sort) ($public | sort) 'every mod.nu export needs a smoke snippet in this test'

    let body = $snippets | values | compact | str join "\n"
    let result = ^$nu.current-exe -n -c $"use dotnu/\n($body)" | complete
    rm --force $example_fixture
    assert equal $result.exit_code 0 $"public-API smoke run failed:\n($result.stderr)"
}
