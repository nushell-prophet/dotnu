# AST Behavior: Block and Closure Boundaries
#
# `ast --flatten` distinguishes between:
# - `shape_block` — control flow blocks (if/else, @example args)
# - `shape_closure` — def bodies, standalone closures
#
# Key observations:
# - Opening `{` may include trailing whitespace in content
# - Closing `}` may include leading whitespace in content
# - Braces are separate tokens (not one token for whole block)

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# --- shape_closure: def body ---

'def foo [] { ls }' | print $in
# => def foo [] { ls }

ast --flatten 'def foo [] { ls }' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ def     │ shape_internalcall │
# => │ 1 │ foo     │ shape_string       │
# => │ 2 │ []      │ shape_signature    │
# => │ 3 │ {       │ shape_closure      │
# => │ 4 │ ls      │ shape_internalcall │
# => │ 5 │  }      │ shape_closure      │
# => ╰───┴─────────┴────────────────────╯

# Note: `{` includes trailing space, `}` includes leading space
ast --flatten 'def foo [] { ls }' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ def     │     0 │   3 │
# => │ 1 │ foo     │     4 │   7 │
# => │ 2 │ []      │     8 │  10 │
# => │ 3 │ {       │    11 │  13 │
# => │ 4 │ ls      │    13 │  15 │
# => │ 5 │  }      │    15 │  17 │
# => ╰───┴─────────┴───────┴─────╯

# --- shape_closure: standalone closure ---

'{|x| $x + 1}' | print $in
# => {|x| $x + 1}

# Closure params `|x|` are included with opening brace
ast --flatten '{|x| $x + 1}' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ {|x|    │ shape_closure  │
# => │ 1 │ $x      │ shape_variable │
# => │ 2 │ +       │ shape_operator │
# => │ 3 │ 1       │ shape_int      │
# => │ 4 │ }       │ shape_closure  │
# => ╰───┴─────────┴────────────────╯

# --- shape_block: if/else blocks ---

'if true { a } else { b }' | print $in
# => if true { a } else { b }

ast --flatten 'if true { a } else { b }' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ if      │ shape_internalcall │
# => │ 1 │ true    │ shape_bool         │
# => │ 2 │ {       │ shape_block        │
# => │ 3 │ a       │ shape_external     │
# => │ 4 │  }      │ shape_block        │
# => │ 5 │ else    │ shape_keyword      │
# => │ 6 │ {       │ shape_block        │
# => │ 7 │ b       │ shape_external     │
# => │ 8 │  }      │ shape_block        │
# => ╰───┴─────────┴────────────────────╯

# --- shape_block: @example argument ---

'@example "" { ls }' | print $in
# => @example "" { ls }

# Note: `shape_garbage` appears at end (empty span)
ast --flatten '@example "" { ls }' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ example │ shape_internalcall │
# => │ 1 │ ""      │ shape_string       │
# => │ 2 │ {       │ shape_block        │
# => │ 3 │ ls      │ shape_internalcall │
# => │ 4 │  }      │ shape_block        │
# => │ 5 │         │ shape_garbage      │
# => ╰───┴─────────┴────────────────────╯

# The `@` is NOT in the token - it's at position 0, but `example` starts at 1
ast --flatten '@example "" { ls }' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ example │     1 │   8 │
# => │ 1 │ ""      │     9 │  11 │
# => │ 2 │ {       │    12 │  14 │
# => │ 3 │ ls      │    14 │  16 │
# => │ 4 │  }      │    16 │  18 │
# => │ 5 │         │    18 │  18 │
# => ╰───┴─────────┴───────┴─────╯

# --- Nested blocks ---

'if true { if false { x } }' | print $in
# => if true { if false { x } }

ast --flatten 'if true { if false { x } }' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ if      │ shape_internalcall │
# => │ 1 │ true    │ shape_bool         │
# => │ 2 │ {       │ shape_block        │
# => │ 3 │ if      │ shape_internalcall │
# => │ 4 │ false   │ shape_bool         │
# => │ 5 │ {       │ shape_block        │
# => │ 6 │ x       │ shape_external     │
# => │ 7 │  }      │ shape_block        │
# => │ 8 │  }      │ shape_block        │
# => ╰───┴─────────┴────────────────────╯

# --- Multiline block spans ---

"def bar [] {
    ls
}" | print $in
# => def bar [] {
# =>     ls
# => }

# Opening brace includes newline, closing includes leading whitespace
ast --flatten "def bar [] {
    ls
}" | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ def     │     0 │   3 │
# => │ 1 │ bar     │     4 │   7 │
# => │ 2 │ []      │     8 │  10 │
# => │ 3 │ {       │    11 │  17 │
# => │   │         │       │     │
# => │ 4 │ ls      │    17 │  19 │
# => │ 5 │         │    19 │  21 │
# => │   │ }       │       │     │
# => ╰───┴─────────┴───────┴─────╯
