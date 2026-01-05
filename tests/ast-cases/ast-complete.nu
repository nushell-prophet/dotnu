# AST Behavior: ast-complete gap filling
#
# The `ast-complete` command fills gaps in `ast --flatten` output,
# creating a complete token stream where every byte is accounted for.
#
# Synthetic shapes added:
# - shape_semicolon: statement-ending `;`
# - shape_assignment: variable assignment `=`
# - shape_whitespace: spaces between tokens
# - shape_newline: newline characters
# - shape_pipe: pipe operator `|`
# - shape_comma: comma separator `,`
# - shape_gap: unclassified content (like `@` prefix)

source ../../dotnu/commands.nu

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# --- Basic variable assignment ---

'let x = 1;' | print $in
# => let x = 1;

# Standard ast --flatten (missing semicolon and =)
ast --flatten 'let x = 1;' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ 1       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯

# With ast-complete (all bytes covered)
'let x = 1;' | ast-complete | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │         │ shape_whitespace   │
# => │ 2 │ x       │ shape_vardecl      │
# => │ 3 │  =      │ shape_assignment   │
# => │ 4 │ 1       │ shape_int          │
# => │ 5 │ ;       │ shape_semicolon    │
# => ╰───┴─────────┴────────────────────╯

# --- Multiple semicolons ---

'a; b; c' | print $in
# => a; b; c

'a; b; c' | ast-complete | select content shape | print $in
# => ╭───┬─────────┬─────────────────╮
# => │ # │ content │      shape      │
# => ├───┼─────────┼─────────────────┤
# => │ 0 │ a       │ shape_external  │
# => │ 1 │ ;       │ shape_semicolon │
# => │ 2 │ b       │ shape_external  │
# => │ 3 │ ;       │ shape_semicolon │
# => │ 4 │ c       │ shape_external  │
# => ╰───┴─────────┴─────────────────╯

# --- Pipe operator ---

'ls | head' | print $in
# => ls | head

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

# --- Attribute prefix @ becomes shape_gap ---

'@test' | print $in
# => @test

# The @ is captured as shape_gap since it's not part of any token
'@test' | ast-complete | select content shape | print $in
# => ╭───┬─────────┬───────────────╮
# => │ # │ content │     shape     │
# => ├───┼─────────┼───────────────┤
# => │ 0 │ @       │ shape_gap     │
# => │ 1 │ test    │ shape_garbage │
# => │ 2 │         │ shape_garbage │
# => ╰───┴─────────┴───────────────╯

# --- Verify complete byte coverage ---

# Every byte should be accounted for (no gaps between end and next start)
let source = 'let x = 1;'
let tokens = $source | ast-complete
let coverage_ok = $tokens
| window 2
| all {|pair| $pair.0.end == $pair.1.start}
$coverage_ok | print $in
# => true
