# AST Behavior: Operators
#
# How operators are tokenized in `ast --flatten`:
# - Arithmetic: shape_operator (+, -, *, /, mod, **)
# - Comparison: shape_operator (==, !=, <, >, <=, >=)
# - Logical: shape_operator (and, or, not)
# - Range: shape_operator (.., ..=)
# - Pipeline: shape_pipe (|)
#
# Note: Most operators are tokenized, including the pipe operator.

source ../../dotnu/commands.nu

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯


# --- Arithmetic operators ---

'1 + 2' | print $in
# => 1 + 2


ast --flatten '1 + 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ +       │ shape_operator │
# => │ 2 │ 2       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'10 - 3' | print $in
# => 10 - 3


ast --flatten '10 - 3' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 10      │ shape_int      │
# => │ 1 │ -       │ shape_operator │
# => │ 2 │ 3       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'4 * 5' | print $in
# => 4 * 5


ast --flatten '4 * 5' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 4       │ shape_int      │
# => │ 1 │ *       │ shape_operator │
# => │ 2 │ 5       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'10 / 2' | print $in
# => 10 / 2


ast --flatten '10 / 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 10      │ shape_int      │
# => │ 1 │ /       │ shape_operator │
# => │ 2 │ 2       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'2 ** 3' | print $in
# => 2 ** 3


ast --flatten '2 ** 3' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 2       │ shape_int      │
# => │ 1 │ **      │ shape_operator │
# => │ 2 │ 3       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


# --- Comparison operators ---

'1 == 1' | print $in
# => 1 == 1


ast --flatten '1 == 1' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ ==      │ shape_operator │
# => │ 2 │ 1       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'1 != 2' | print $in
# => 1 != 2


ast --flatten '1 != 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ !=      │ shape_operator │
# => │ 2 │ 2       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'1 < 2' | print $in
# => 1 < 2


ast --flatten '1 < 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ <       │ shape_operator │
# => │ 2 │ 2       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


# --- Logical operators ---

'true and false' | print $in
# => true and false


ast --flatten 'true and false' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ true    │ shape_bool     │
# => │ 1 │ and     │ shape_operator │
# => │ 2 │ false   │ shape_bool     │
# => ╰───┴─────────┴────────────────╯


'true or false' | print $in
# => true or false


ast --flatten 'true or false' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ true    │ shape_bool     │
# => │ 1 │ or      │ shape_operator │
# => │ 2 │ false   │ shape_bool     │
# => ╰───┴─────────┴────────────────╯


'not true' | print $in
# => not true


ast --flatten 'not true' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ not     │ shape_operator │
# => │ 1 │ true    │ shape_bool     │
# => ╰───┴─────────┴────────────────╯


# --- Range operators ---

'1..5' | print $in
# => 1..5


ast --flatten '1..5' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ ..      │ shape_operator │
# => │ 2 │ 5       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


'1..<5' | print $in
# => 1..<5


ast --flatten '1..<5' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ 1       │ shape_int      │
# => │ 1 │ ..<     │ shape_operator │
# => │ 2 │ 5       │ shape_int      │
# => ╰───┴─────────┴────────────────╯


# --- Pipeline operator ---

'ls | head' | print $in
# => ls | head


# Pipe operator is tokenized as shape_pipe
ast --flatten 'ls | head' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ ls      │ shape_internalcall │
# => │ 1 │ |       │ shape_pipe         │
# => │ 2 │ head    │ shape_external     │
# => ╰───┴─────────┴────────────────────╯


# ast-complete adds whitespace tokens between other tokens
'ls | head' | ast-complete | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ ls      │ shape_internalcall │
# => │ 1 │         │ shape_whitespace   │
# => │ 2 │ |       │ shape_pipe         │
# => │ 3 │         │ shape_whitespace   │
# => │ 4 │ head    │ shape_external     │
# => ╰───┴─────────┴────────────────────╯

