# AST Behavior: `ast --json` Basic Output Structure
#
# The `ast --json` command returns a record with two fields:
# - `block`: JSON string containing the full AST
# - `error`: JSON string (usually "null") for parse errors
#
# The block contains:
# - `signature`: metadata about the parsed code (usually empty for snippets)
# - `pipelines`: array of pipelines, each with `elements`
# - `captures`: variables captured from outer scope
# - `ir_block`: intermediate representation (for execution)
# - `span`: byte range of the entire block
#
# Each pipeline element has:
# - `pipe`: span of the `|` operator (null for first element)
# - `expr`: the expression with `{expr, span, span_id, ty}`
# - `redirection`: any output redirection
#
# IMPORTANT: Spans are absolute byte offsets in Nushell's internal buffer,
# NOT relative to the input string. To get relative positions, subtract
# the block's base span.start from all span values.

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# ============================================================
# SIMPLE LITERALS
# ============================================================

# --- Integer literal ---

'1' | print $in
# => 1

# The expression type is `Int` with the integer value
ast --json '1'
| get block
| from json
| get pipelines.0.elements.0.expr
| select expr ty
| to nuon
| print $in
# => {expr: {Int: 1}, ty: Int}

# --- String literal ---

'"hello"' | print $in
# => "hello"

# String expression contains the string value (without quotes)
ast --json '"hello"'
| get block
| from json
| get pipelines.0.elements.0.expr
| select expr ty
| to nuon
| print $in
# => {expr: {String: hello}, ty: String}

# --- Float literal ---

'3.14' | print $in
# => 3.14

ast --json '3.14'
| get block
| from json
| get pipelines.0.elements.0.expr
| select expr ty
| to nuon
| print $in
# => {expr: {Float: 3.14}, ty: Float}

# --- Boolean literal ---

'true' | print $in
# => true

ast --json 'true'
| get block
| from json
| get pipelines.0.elements.0.expr
| select expr ty
| to nuon
| print $in
# => {expr: {Bool: true}, ty: Bool}

# --- Null literal ---

'null' | print $in
# => null

ast --json 'null'
| get block
| from json
| get pipelines.0.elements.0.expr
| select expr ty
| to nuon
| print $in
# => {expr: Nothing, ty: Nothing}

# ============================================================
# BINARY OPERATORS
# ============================================================

# --- Arithmetic: addition ---

'1 + 2' | print $in
# => 1 + 2

# BinaryOp contains three elements: [lhs, operator, rhs]
ast --json '1 + 2'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.BinaryOp
| each {|e| $e.expr}
| to nuon
| print $in
# => [{Int: 1}, {Operator: {Math: Add}}, {Int: 2}]

# --- Comparison: greater than ---

'5 > 3' | print $in
# => 5 > 3

ast --json '5 > 3'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.BinaryOp
| each {|e| $e.expr}
| to nuon
| print $in
# => [{Int: 5}, {Operator: {Comparison: GreaterThan}}, {Int: 3}]

# --- Logical: and ---

'true and false' | print $in
# => true and false

ast --json 'true and false'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.BinaryOp
| each {|e| $e.expr}
| to nuon
| print $in
# => [{Bool: true}, {Operator: {Boolean: And}}, {Bool: false}]

# ============================================================
# COMMAND CALLS
# ============================================================

# --- Simple command (no arguments) ---

'ls' | print $in
# => ls

# Call expression has decl_id (command ID), head span, and arguments
# Note: decl_id varies by Nushell installation; we verify structure only
ast --json 'ls'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call
| get arguments
| to nuon
| print $in
# => []

# Verify head span length is 2 (for "ls")
let ast_ls = ast --json 'ls' | get block | from json
let base_ls = $ast_ls.span.start
let head_ls = $ast_ls.pipelines.0.elements.0.expr.expr.Call.head
($head_ls.end - $head_ls.start) | print $in
# => 2

# --- Command with argument ---

'echo hello' | print $in
# => echo hello

# Arguments are wrapped in Positional variant
# Extract just the expression type to avoid span variations
ast --json 'echo hello'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional
| select expr ty
| to nuon
| print $in
# => {expr: {String: hello}, ty: String}

# ============================================================
# PIPELINES
# ============================================================

# --- Two-stage pipeline ---

'ls | length' | print $in
# => ls | length

# Pipeline has multiple elements; second element has `pipe` span
# First element has null pipe, second has non-null pipe
ast --json 'ls | length'
| get block
| from json
| get pipelines.0.elements
| each {|e| $e.pipe != null}
| to nuon
| print $in
# => [false, true]

# Verify pipe span length is 1 (for "|")
let ast_pipe = ast --json 'ls | length' | get block | from json
let pipe_span = $ast_pipe.pipelines.0.elements.1.pipe
($pipe_span.end - $pipe_span.start) | print $in
# => 1

# --- Three-stage pipeline ---

'ls | where size > 1kb | length' | print $in
# => ls | where size > 1kb | length

ast --json 'ls | where size > 1kb | length'
| get block
| from json
| get pipelines.0.elements
| length
| print $in
# => 3

# First element has null pipe, others have pipe spans
ast --json 'ls | where size > 1kb | length'
| get block
| from json
| get pipelines.0.elements
| each {|e| $e.pipe != null}
| to nuon
| print $in
# => [false, true, true]

# ============================================================
# COLLECTION LITERALS
# ============================================================

# --- List literal ---

'[1, 2, 3]' | print $in
# => [1, 2, 3]

# Lists are wrapped in FullCellPath (allows .0 access)
ast --json '[1, 2, 3]'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.FullCellPath.head.expr.List
| each {|item| $item.Item.expr}
| to nuon
| print $in
# => [[Int]; [1], [2], [3]]

# --- Record literal ---

'{a: 1, b: 2}' | print $in
# => {a: 1, b: 2}

# Records store key-value pairs
ast --json '{a: 1, b: 2}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.FullCellPath.head.expr.Record
| each {|pair|
    let kv = $pair.Pair
    {key: $kv.0.expr, value: $kv.1.expr}
}
| to nuon
| print $in
# => [[key, value]; [{String: a}, {Int: 1}], [{String: b}, {Int: 2}]]

# ============================================================
# VARIABLES
# ============================================================

# --- Built-in variable ---

'$nu' | print $in
# => $nu

# Variables reference by ID; Var: 0 is $nu
ast --json '$nu'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.FullCellPath.head.expr
| to nuon
| print $in
# => {Var: 0}

# --- Undefined variable ---

'$undefined_var' | print $in
# => $undefined_var

# Undefined variables parse as Garbage (string representation)
ast --json '$undefined_var'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.FullCellPath.head.expr
| to nuon
| print $in
# => "Garbage"

# ============================================================
# VARIABLE DECLARATIONS
# ============================================================

# --- let statement ---

'let x = 1' | print $in
# => let x = 1

# `let` is a Call with VarDecl and Block arguments
ast --json 'let x = 1'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg | columns | first}
| to nuon
| print $in
# => [Positional, Positional]

# First argument is a VarDecl (variable declaration ID)
# The ID varies, so we just verify it's a VarDecl record
ast --json 'let x = 1'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| columns
| to nuon
| print $in
# => [VarDecl]

# ============================================================
# TOP-LEVEL STRUCTURE
# ============================================================

# --- Raw output structure ---

'1' | print $in
# => 1

# ast --json returns {block: string, error: string}
ast --json '1' | columns | to nuon | print $in
# => [block, error]

# The block must be parsed from JSON
ast --json '1' | get error | print $in
# => null

# --- Block structure fields ---

ast --json '1'
| get block
| from json
| columns
| to nuon
| print $in
# => [signature, pipelines, captures, redirect_env, ir_block, span]

# ============================================================
# RELATIVE SPAN CALCULATION
# ============================================================

# Spans are absolute byte offsets in Nushell's internal buffer.
# To get positions relative to your input string, subtract block.span.start.

'1 + 2' | print $in
# => 1 + 2

let ast = ast --json '1 + 2' | get block | from json
let base = $ast.span.start
let ops = $ast | get pipelines.0.elements.0.expr.expr.BinaryOp

# Convert absolute spans to relative positions
$ops
| each {|e| {start: ($e.span.start - $base), end: ($e.span.end - $base)}}
| to nuon
| print $in
# => [[start, end]; [0, 1], [2, 3], [4, 5]]

# Relative spans correspond to source positions:
# "1 + 2"
#  ^     span 0-1 = "1"
#    ^   span 2-3 = "+"
#      ^ span 4-5 = "2"

# Verify by extracting source text using relative spans
# Note: spans use exclusive end, so use ..<rel_end
let source = '1 + 2'
$ops
| each {|e|
    let rel_start = $e.span.start - $base
    let rel_end = $e.span.end - $base
    $source | str substring $rel_start..<$rel_end
}
| to nuon
| print $in
# => [1, +, 2]
