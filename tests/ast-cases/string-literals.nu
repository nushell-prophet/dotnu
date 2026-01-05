# AST Behavior: String Literals
#
# How different string types are tokenized in `ast --flatten`:
# - Single quotes: shape_string
# - Double quotes: shape_string
# - Interpolated strings `$"..."`: shape_string with nested expressions
# - Raw strings: shape_rawstring
# - Backtick strings: shape_string
#
# All string types preserve their quote characters in the content field.

source ../../dotnu/commands.nu

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯


# --- Single-quoted strings ---

"'hello'" | print $in
# => 'hello'


ast --flatten "'hello'" | select content shape | print $in
# => ╭───┬─────────┬──────────────╮
# => │ # │ content │    shape     │
# => ├───┼─────────┼──────────────┤
# => │ 0 │ 'hello' │ shape_string │
# => ╰───┴─────────┴──────────────╯


# --- Double-quoted strings ---

'"hello"' | print $in
# => "hello"


ast --flatten '"hello"' | select content shape | print $in
# => ╭───┬─────────┬──────────────╮
# => │ # │ content │    shape     │
# => ├───┼─────────┼──────────────┤
# => │ 0 │ "hello" │ shape_string │
# => ╰───┴─────────┴──────────────╯


# --- Interpolated strings ---

'$"value: (1 + 1)"' | print $in
# => $"value: (1 + 1)"


# Interpolated strings contain nested expressions
ast --flatten '$"value: (1 + 1)"' | select content shape | print $in
# => ╭───┬─────────┬────────────────────────────╮
# => │ # │ content │           shape            │
# => ├───┼─────────┼────────────────────────────┤
# => │ 0 │ $"      │ shape_string_interpolation │
# => │ 1 │ value:  │ shape_string               │
# => │ 2 │ (       │ shape_block                │
# => │ 3 │ 1       │ shape_int                  │
# => │ 4 │ +       │ shape_operator             │
# => │ 5 │ 1       │ shape_int                  │
# => │ 6 │ )       │ shape_block                │
# => │ 7 │ "       │ shape_string_interpolation │
# => ╰───┴─────────┴────────────────────────────╯


# --- Raw strings ---

"r#'raw string'#" | print $in
# => r#'raw string'#


ast --flatten "r#'raw string'#" | select content shape | print $in
# => ╭───┬─────────────────┬──────────────────╮
# => │ # │     content     │      shape       │
# => ├───┼─────────────────┼──────────────────┤
# => │ 0 │ r#'raw string'# │ shape_raw_string │
# => ╰───┴─────────────────┴──────────────────╯


# --- Backtick strings (for external commands) ---

'`echo hello`' | print $in
# => `echo hello`


ast --flatten '`echo hello`' | select content shape | print $in
# => ╭───┬──────────────┬────────────────╮
# => │ # │   content    │     shape      │
# => ├───┼──────────────┼────────────────┤
# => │ 0 │ `echo hello` │ shape_external │
# => ╰───┴──────────────┴────────────────╯


# --- Multiline strings ---

"'line1\nline2'" | print $in
# => 'line1
# => line2'


ast --flatten "'line1\nline2'" | select content shape | print $in
# => ╭───┬─────────┬──────────────╮
# => │ # │ content │    shape     │
# => ├───┼─────────┼──────────────┤
# => │ 0 │ 'line1  │ shape_string │
# => │   │ line2'  │              │
# => ╰───┴─────────┴──────────────╯


# --- String with escape sequences ---

'"hello\nworld"' | print $in
# => "hello\nworld"


ast --flatten '"hello\nworld"' | select content shape | print $in
# => ╭───┬────────────────┬──────────────╮
# => │ # │    content     │    shape     │
# => ├───┼────────────────┼──────────────┤
# => │ 0 │ "hello\nworld" │ shape_string │
# => ╰───┴────────────────┴──────────────╯


# --- Empty strings ---

'""' | print $in
# => ""


ast --flatten '""' | select content shape | print $in
# => ╭───┬─────────┬──────────────╮
# => │ # │ content │    shape     │
# => ├───┼─────────┼──────────────┤
# => │ 0 │ ""      │ shape_string │
# => ╰───┴─────────┴──────────────╯


"''" | print $in
# => ''


ast --flatten "''" | select content shape | print $in
# => ╭───┬─────────┬──────────────╮
# => │ # │ content │    shape     │
# => ├───┼─────────┼──────────────┤
# => │ 0 │ ''      │ shape_string │
# => ╰───┴─────────┴──────────────╯

