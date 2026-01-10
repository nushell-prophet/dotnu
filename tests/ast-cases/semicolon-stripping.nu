# AST Behavior: Semicolon and Assignment Operator Stripping
#
# `ast --flatten` omits certain syntax elements from its output:
# - Statement-ending semicolons (`;`)
# - Variable assignment operators (`=` in `let x = 1`)
#
# These can be inferred from gaps in byte spans, but are not tokenized.
# Nushell version at time of writing: see `version` output below.

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# --- Semicolons are stripped ---

# Single statement with trailing semicolon
'let x = 1;' | print $in
# => let x = 1;

ast --flatten 'let x = 1;' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ 1       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯

# The semicolon at position 9 is not tokenized (string is 10 bytes: 0-9)
ast --flatten 'let x = 1;' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ let     │     0 │   3 │
# => │ 1 │ x       │     4 │   5 │
# => │ 2 │ 1       │     8 │   9 │
# => ╰───┴─────────┴───────┴─────╯

# --- Multiple semicolon-separated statements ---

'a; b; c' | print $in
# => a; b; c

ast --flatten 'a; b; c' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ a       │ shape_external │
# => │ 1 │ b       │ shape_external │
# => │ 2 │ c       │ shape_external │
# => ╰───┴─────────┴────────────────╯

# Gaps at positions 1-2 and 4-5 indicate semicolons + spaces
ast --flatten 'a; b; c' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ a       │     0 │   1 │
# => │ 1 │ b       │     3 │   4 │
# => │ 2 │ c       │     6 │   7 │
# => ╰───┴─────────┴───────┴─────╯

# --- Assignment operator is also stripped ---

# The `=` in variable assignment is not tokenized
'let x = 1' | print $in
# => let x = 1

# Note: positions 5-7 (` = `) have no token
ast --flatten 'let x = 1' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ let     │     0 │   3 │
# => │ 1 │ x       │     4 │   5 │
# => │ 2 │ 1       │     8 │   9 │
# => ╰───┴─────────┴───────┴─────╯

# --- Comparison operators ARE preserved ---

# Unlike assignment `=`, comparison `==` appears as shape_operator
ast --flatten 'if 1 == 2 { }' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ if      │ shape_internalcall │
# => │ 1 │ 1       │ shape_int          │
# => │ 2 │ ==      │ shape_operator     │
# => │ 3 │ 2       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯

# --- Semicolons inside strings are preserved ---

# String content is not parsed, so `;` inside quotes remains
ast --flatten 'let x = "a;b"' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ "a;b"   │ shape_string       │
# => ╰───┴─────────┴────────────────────╯
