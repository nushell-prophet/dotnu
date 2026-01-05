# AST Behavior: Attribute Detection (@example, @test, etc.)
#
# The `@` prefix is NOT included in the token content.
# Detection requires checking the byte at (span.start - 1).
#
# Attribute shapes vary:
# - @example, @deprecated → shape_internalcall (has arguments or recognized)
# - @test → shape_garbage (no arguments, unrecognized?)
#
# This is the method dotnu uses in list-module-commands.

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# --- @example attribute ---

'@example "desc" { code } --result 42
def bar [] {}' | print $in
# => @example "desc" { code } --result 42
# => def bar [] {}

ast --flatten '@example "desc" { code } --result 42
def bar [] {}' | select content shape | print $in
# => ╭────┬──────────┬────────────────────╮
# => │  # │ content  │       shape        │
# => ├────┼──────────┼────────────────────┤
# => │  0 │ example  │ shape_internalcall │
# => │  1 │ "desc"   │ shape_string       │
# => │  2 │ {        │ shape_block        │
# => │  3 │ code     │ shape_external     │
# => │  4 │  }       │ shape_block        │
# => │  5 │ --result │ shape_flag         │
# => │  6 │ 42       │ shape_int          │
# => │  7 │ def      │ shape_internalcall │
# => │  8 │ bar      │ shape_string       │
# => │  9 │ []       │ shape_signature    │
# => │ 10 │ {}       │ shape_closure      │
# => ╰────┴──────────┴────────────────────╯

# `example` starts at position 1 (@ is at 0)
ast --flatten '@example "desc" { code } --result 42
def bar [] {}' | flatten span | select content start end | first 7 | print $in
# => ╭───┬──────────┬───────┬─────╮
# => │ # │ content  │ start │ end │
# => ├───┼──────────┼───────┼─────┤
# => │ 0 │ example  │     1 │   8 │
# => │ 1 │ "desc"   │     9 │  15 │
# => │ 2 │ {        │    16 │  18 │
# => │ 3 │ code     │    18 │  22 │
# => │ 4 │  }       │    22 │  24 │
# => │ 5 │ --result │    25 │  33 │
# => │ 6 │ 42       │    34 │  36 │
# => ╰───┴──────────┴───────┴─────╯

# --- @test attribute ---

'@test
def foo [] {}' | print $in
# => @test
# => def foo [] {}

# Note: @test is shape_garbage (not shape_internalcall)
ast --flatten '@test
def foo [] {}' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ test    │ shape_garbage      │
# => │ 1 │ def     │ shape_internalcall │
# => │ 2 │ foo     │ shape_string       │
# => │ 3 │ []      │ shape_signature    │
# => │ 4 │ {}      │ shape_closure      │
# => ╰───┴─────────┴────────────────────╯

# Still starts at position 1
ast --flatten '@test
def foo [] {}' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ test    │     1 │   5 │
# => │ 1 │ def     │     6 │   9 │
# => │ 2 │ foo     │    10 │  13 │
# => │ 3 │ []      │    14 │  16 │
# => │ 4 │ {}      │    17 │  19 │
# => ╰───┴─────────┴───────┴─────╯

# --- @deprecated attribute ---

'@deprecated
def old [] {}' | print $in
# => @deprecated
# => def old [] {}

ast --flatten '@deprecated
def old [] {}' | select content shape | print $in
# => ╭───┬────────────┬────────────────────╮
# => │ # │  content   │       shape        │
# => ├───┼────────────┼────────────────────┤
# => │ 0 │ deprecated │ shape_internalcall │
# => │ 1 │ def        │ shape_internalcall │
# => │ 2 │ old        │ shape_string       │
# => │ 3 │ []         │ shape_signature    │
# => │ 4 │ {}         │ shape_closure      │
# => ╰───┴────────────┴────────────────────╯

# --- Detection method: check byte before token ---

# Simulate dotnu's attribute detection:
# If byte at (start - 1) is '@', it's an attribute
let code = '@example "x" { y }
def z [] {}'
let tokens = ast --flatten $code | flatten span
let code_bytes = $code | encode utf8
$tokens | where {|t| $t.start > 0 and (($code_bytes | bytes at ($t.start - 1)..<($t.start) | decode utf8) == '@')} | select content start | print $in
# => ╭───┬─────────┬───────╮
# => │ # │ content │ start │
# => ├───┼─────────┼───────┤
# => │ 0 │ example │     1 │
# => ╰───┴─────────┴───────╯

# --- False positives: @ inside strings ---

'let x = "has @test inside"' | print $in
# => let x = "has @test inside"

# The @test inside string is NOT a separate token
ast --flatten 'let x = "has @test inside"' | select content shape | print $in
# => ╭───┬────────────────────┬────────────────────╮
# => │ # │      content       │       shape        │
# => ├───┼────────────────────┼────────────────────┤
# => │ 0 │ let                │ shape_internalcall │
# => │ 1 │ x                  │ shape_vardecl      │
# => │ 2 │ "has @test inside" │ shape_string       │
# => ╰───┴────────────────────┴────────────────────╯

# --- Comments are not tokenized ---

'# comment with @test' | print $in
# => # comment with @test

# Comments produce empty AST
ast --flatten '# comment with @test' | length | print $in
# => 0
