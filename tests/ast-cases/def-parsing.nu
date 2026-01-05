# AST Behavior: def/export def Parsing
#
# How command definitions are tokenized:
# - `export def` is a SINGLE token (not two separate tokens)
# - Command name is shape_string (quotes preserved if present)
# - Signature [...] is a single shape_signature token
# - Body {...} is shape_closure
#
# This affects how dotnu extracts command names.

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# --- Basic def ---

'def foo [] {}' | print $in
# => def foo [] {}

ast --flatten 'def foo [] {}' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ def     │ shape_internalcall │
# => │ 1 │ foo     │ shape_string       │
# => │ 2 │ []      │ shape_signature    │
# => │ 3 │ {}      │ shape_closure      │
# => ╰───┴─────────┴────────────────────╯

# --- export def is ONE token ---

'export def bar [] {}' | print $in
# => export def bar [] {}

# Note: "export def" is a single shape_internalcall token
ast --flatten 'export def bar [] {}' | select content shape | print $in
# => ╭───┬────────────┬────────────────────╮
# => │ # │  content   │       shape        │
# => ├───┼────────────┼────────────────────┤
# => │ 0 │ export def │ shape_internalcall │
# => │ 1 │ bar        │ shape_string       │
# => │ 2 │ []         │ shape_signature    │
# => │ 3 │ {}         │ shape_closure      │
# => ╰───┴────────────┴────────────────────╯

# Span shows it's one token spanning both words
ast --flatten 'export def bar [] {}' | flatten span | select content start end | print $in
# => ╭───┬────────────┬───────┬─────╮
# => │ # │  content   │ start │ end │
# => ├───┼────────────┼───────┼─────┤
# => │ 0 │ export def │     0 │  10 │
# => │ 1 │ bar        │    11 │  14 │
# => │ 2 │ []         │    15 │  17 │
# => │ 3 │ {}         │    18 │  20 │
# => ╰───┴────────────┴───────┴─────╯

# --- def with flags ---

'def --env --wrapped "my cmd" [] {}' | print $in
# => def --env --wrapped "my cmd" [] {}

# Flags appear between def and command name
ast --flatten 'def --env --wrapped "my cmd" [] {}' | select content shape | print $in
# => ╭───┬───────────┬────────────────────╮
# => │ # │  content  │       shape        │
# => ├───┼───────────┼────────────────────┤
# => │ 0 │ def       │ shape_internalcall │
# => │ 1 │ --env     │ shape_flag         │
# => │ 2 │ --wrapped │ shape_flag         │
# => │ 3 │ "my cmd"  │ shape_string       │
# => │ 4 │ []        │ shape_signature    │
# => │ 5 │ {}        │ shape_closure      │
# => ╰───┴───────────┴────────────────────╯

# --- Command name with quotes ---

'def "sub cmd" [] {}' | print $in
# => def "sub cmd" [] {}

# Quotes are preserved in content
ast --flatten 'def "sub cmd" [] {}' | select content shape | print $in
# => ╭───┬───────────┬────────────────────╮
# => │ # │  content  │       shape        │
# => ├───┼───────────┼────────────────────┤
# => │ 0 │ def       │ shape_internalcall │
# => │ 1 │ "sub cmd" │ shape_string       │
# => │ 2 │ []        │ shape_signature    │
# => │ 3 │ {}        │ shape_closure      │
# => ╰───┴───────────┴────────────────────╯

# --- Signature is a single token ---

'def foo [x: int, y?: string] {}' | print $in
# => def foo [x: int, y?: string] {}

# Entire signature including params is one shape_signature token
ast --flatten 'def foo [x: int, y?: string] {}' | select content shape | print $in
# => ╭───┬──────────────────────┬────────────────────╮
# => │ # │       content        │       shape        │
# => ├───┼──────────────────────┼────────────────────┤
# => │ 0 │ def                  │ shape_internalcall │
# => │ 1 │ foo                  │ shape_string       │
# => │ 2 │ [x: int, y?: string] │ shape_signature    │
# => │ 3 │ {}                   │ shape_closure      │
# => ╰───┴──────────────────────┴────────────────────╯

# --- export def main ---

'export def main [] {}' | print $in
# => export def main [] {}

ast --flatten 'export def main [] {}' | select content shape | print $in
# => ╭───┬────────────┬────────────────────╮
# => │ # │  content   │       shape        │
# => ├───┼────────────┼────────────────────┤
# => │ 0 │ export def │ shape_internalcall │
# => │ 1 │ main       │ shape_string       │
# => │ 2 │ []         │ shape_signature    │
# => │ 3 │ {}         │ shape_closure      │
# => ╰───┴────────────┴────────────────────╯

# --- Finding command name: first shape_string after def ---

# To extract command name: find def/export def token,
# then get first shape_string (skipping any shape_flag tokens)
ast --flatten 'export def --env "my-cmd" [x] { ls }'
| select content shape
| skip until {|r| $r.content =~ 'def$'}
| skip 1
| skip while {|r| $r.shape == 'shape_flag'}
| first
| print $in
# => ╭─────────┬──────────────╮
# => │ content │ "my-cmd"     │
# => │ shape   │ shape_string │
# => ╰─────────┴──────────────╯
