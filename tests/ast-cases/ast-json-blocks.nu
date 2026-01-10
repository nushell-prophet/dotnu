# AST Behavior: `ast --json` Blocks, Closures, and Control Flow
#
# This file documents how Nushell's AST represents:
# - Closures (code in braces, with or without parameters)
# - Blocks (used internally by control flow constructs)
# - Control flow expressions (if, match, loops, try-catch)
#
# Key insight: In Nushell 0.109.x, standalone `{ code }` is represented as
# a Closure in the AST. The Block type appears as arguments to control flow
# commands (if, for, while, loop, try). This differs from earlier versions
# where Block and Closure were more distinct at the syntax level.

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# ============================================================
# CLOSURES (Standalone Braces)
# ============================================================

# --- Simple braces are closures ---

'{ 1 + 2 }' | print $in
# => { 1 + 2 }

# In 0.109.x, `{ code }` is parsed as Closure with a block_id
ast --json '{ 1 + 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Closure]

# The Closure value is just an integer block_id (not a record)
ast --json '{ 1 + 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Closure
| describe
| print $in
# => int

# Type is Closure
ast --json '{ 1 + 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.ty
| print $in
# => Closure

# --- Explicit closure with empty parameter list ---

'{|| 42}' | print $in
# => {|| 42}

# Same structure as braces without parameters
ast --json '{|| 42}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Closure]

ast --json '{|| 42}'
| get block
| from json
| get pipelines.0.elements.0.expr.ty
| print $in
# => Closure

# --- Closure with one parameter ---

'{|x| $x + 1}' | print $in
# => {|x| $x + 1}

# Parameter closures have the same Closure wrapper
ast --json '{|x| $x + 1}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Closure]

ast --json '{|x| $x + 1}'
| get block
| from json
| get pipelines.0.elements.0.expr.ty
| print $in
# => Closure

# --- Closure with type annotation ---

'{|x: int| $x + 1}' | print $in
# => {|x: int| $x + 1}

# Type annotations don't change the outer structure
ast --json '{|x: int| $x + 1}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Closure]

# --- Closure with multiple parameters ---

'{|x, y| $x + $y}' | print $in
# => {|x, y| $x + $y}

ast --json '{|x, y| $x + $y}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Closure]

# ============================================================
# IF EXPRESSIONS
# ============================================================

# --- Simple if-else ---

'if true { 1 } else { 2 }' | print $in
# => if true { 1 } else { 2 }

# If is represented as a Call to the `if` command
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Arguments structure: [condition, then-block, else-keyword-with-block]
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|a| $a.Positional.expr | columns | first}
| to nuon
| print $in
# => [Bool, Block, Keyword]

# First argument: the condition (Bool: true)
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| to nuon
| print $in
# => {Bool: true}

# Second argument: then-block (Block with block_id)
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.Block
| describe
| print $in
# => int

# Third argument: Keyword containing the else block
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.2.Positional.expr.Keyword
| columns
| to nuon
| print $in
# => [keyword, span, expr]

# The else Keyword wraps another expression (Block or nested if)
ast --json 'if true { 1 } else { 2 }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.2.Positional.expr.Keyword.expr
| columns
| to nuon
| print $in
# => [expr, span, span_id, ty]

# --- If-else-if chain ---

'if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }' | print $in
# => if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }

# Still a Call with same argument structure
ast --json 'if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Same 3-argument structure: condition, then-block, else-keyword
ast --json 'if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| length
| print $in
# => 3

# First argument is the comparison $x > 0
ast --json 'if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| columns
| to nuon
| print $in
# => [BinaryOp]

# The else Keyword contains a nested if expression
ast --json 'if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.2.Positional.expr.Keyword.expr
| columns
| to nuon
| print $in
# => [expr, span, span_id, ty]

# ============================================================
# MATCH EXPRESSIONS
# ============================================================

# --- Simple match ---

'match 1 { 1 => "one", _ => "other" }' | print $in
# => match 1 { 1 => "one", _ => "other" }

# Match is a Call to the `match` command
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Match has 2 arguments: scrutinee and match block
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| length
| print $in
# => 2

# First argument is the scrutinee (value being matched)
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| to nuon
| print $in
# => {Int: 1}

# Second argument is a MatchBlock containing the arms
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr
| columns
| to nuon
| print $in
# => [MatchBlock]

# MatchBlock is a list of arms
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.MatchBlock
| length
| print $in
# => 2

# Each arm is a pair: [match_pattern, result_expression]
# First arm: pattern matching 1
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.MatchBlock.0.0.pattern
| columns
| to nuon
| print $in
# => [Expression]

# Second arm: wildcard pattern (_)
ast --json 'match 1 { 1 => "one", _ => "other" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.MatchBlock.1.0.pattern
| to nuon
| print $in
# => IgnoreValue

# ============================================================
# FOR LOOP
# ============================================================

# --- Basic for loop ---

'for x in [1 2 3] { $x }' | print $in
# => for x in [1 2 3] { $x }

# For is a Call to the `for` command
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Arguments: VarDecl, Keyword (in), Block
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|a| $a.Positional.expr | columns | first}
| to nuon
| print $in
# => [VarDecl, Keyword, Block]

# First argument: the loop variable declaration
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| columns
| to nuon
| print $in
# => [VarDecl]

# Second argument: Keyword "in" wrapping the iterable
# Note: keyword is serialized as byte array (ASCII: 105='i', 110='n')
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.Keyword.keyword
| to nuon
| print $in
# => [105, 110]

# The Keyword's expr is a full expression record
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.Keyword.expr
| columns
| to nuon
| print $in
# => [expr, span, span_id, ty]

# Third argument: the body block
ast --json 'for x in [1 2 3] { $x }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.2.Positional.expr.Block
| describe
| print $in
# => int

# ============================================================
# WHILE LOOP
# ============================================================

# --- Basic while loop ---

'while true { break }' | print $in
# => while true { break }

# While is a Call to the `while` command
ast --json 'while true { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Arguments: condition (Bool), body (Block)
ast --json 'while true { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|a| $a.Positional.expr | columns | first}
| to nuon
| print $in
# => [Bool, Block]

# First argument: the condition
ast --json 'while true { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| to nuon
| print $in
# => {Bool: true}

# Second argument: the body block
ast --json 'while true { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr
| columns
| to nuon
| print $in
# => [Block]

# ============================================================
# LOOP (INFINITE)
# ============================================================

# --- Infinite loop ---

'loop { break }' | print $in
# => loop { break }

# Loop is a Call to the `loop` command
ast --json 'loop { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Loop has 1 argument: the body block
ast --json 'loop { break }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|a| $a.Positional.expr | columns | first}
| to nuon
| print $in
# => [Block]

# ============================================================
# TRY-CATCH
# ============================================================

# --- Basic try-catch ---

'try { error make {msg: "fail"} } catch { "caught" }' | print $in
# => try { error make {msg: "fail"} } catch { "caught" }

# Try is a Call to the `try` command
ast --json 'try { error make {msg: "fail"} } catch { "caught" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| to nuon
| print $in
# => [Call]

# Arguments: try-block, catch-keyword
ast --json 'try { error make {msg: "fail"} } catch { "caught" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|a| $a.Positional.expr | columns | first}
| to nuon
| print $in
# => [Block, Keyword]

# First argument: the try block
ast --json 'try { error make {msg: "fail"} } catch { "caught" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| columns
| to nuon
| print $in
# => [Block]

# Second argument: Keyword "catch" wrapping the handler
# Note: keyword as bytes (ASCII: 99='c', 97='a', 116='t', 99='c', 104='h')
ast --json 'try { error make {msg: "fail"} } catch { "caught" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.Keyword.keyword
| to nuon
| print $in
# => [99, 97, 116, 99, 104]

# The catch handler expression (Closure for error binding)
ast --json 'try { error make {msg: "fail"} } catch { "caught" }'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr.Keyword.expr
| columns
| to nuon
| print $in
# => [expr, span, span_id, ty]

# ============================================================
# BLOCK VS CLOSURE SUMMARY
# ============================================================

# In Nushell 0.109.x:
# - Standalone `{ code }` is Closure in the AST
# - Control flow bodies (if, for, while, loop, try) use Block
# - `catch` handler uses Closure (can capture error)
# - Block is an internal type, Closure is user-facing

# Closure: standalone braces or with parameters
'{ 42 }' | do { ast --json $in | get block | from json | get pipelines.0.elements.0.expr | select expr.Closure ty | to nuon } | print $in
# => {"expr.Closure": 337, ty: Closure}

'{|x| $x}' | do { ast --json $in | get block | from json | get pipelines.0.elements.0.expr | select expr.Closure ty | to nuon } | print $in
# => {"expr.Closure": 337, ty: Closure}

# Block: used in control flow (shown via if)
'if true { 1 } else { 2 }' | do {
    ast --json $in
    | get block
    | from json
    | get pipelines.0.elements.0.expr.expr.Call.arguments.1.Positional.expr
    | columns
    | first
} | print $in
# => Block
