# AST Behavior: `ast --json` Span Mapping
#
# Spans in `ast --json` represent byte positions in source code.
# Each span has `start` (inclusive) and `end` (exclusive) byte offsets.
#
# Key concepts:
# - Spans are absolute byte offsets in Nushell's internal buffer
# - To get relative positions, subtract block.span.start from all values
# - For UTF-8 strings, span length may exceed character count
# - Parent spans encompass all child spans
# - Adjacent tokens may have gaps (whitespace) between spans
#
# To extract source text from a span:
#   $source | encode utf8 | bytes at $span.start..<$span.end | decode utf8
#
# Or for ASCII-only content:
#   $source | str substring $rel_start..<$rel_end

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# ============================================================
# SINGLE CHARACTER SPANS
# ============================================================

# --- Integer literal `1` ---

'1' | print $in
# => 1

# The span for a single digit is exactly 1 byte
let ast = ast --json '1' | get block | from json
let base = $ast.span.start
let expr_span = $ast.pipelines.0.elements.0.expr.span
{start: ($expr_span.start - $base), end: ($expr_span.end - $base), length: ($expr_span.end - $expr_span.start)}
| to nuon
| print $in
# => {start: 0, end: 1, length: 1}

# Verify we can extract the character using the span
let source = '1'
$source | str substring 0..<1 | print $in
# => 1

# ============================================================
# MULTI-BYTE CHARACTERS (UTF-8)
# ============================================================

# --- Japanese string "日本語" ---

'"日本語"' | print $in
# => "日本語"

# Each kanji character is 3 bytes in UTF-8
# "日" = 3 bytes, "本" = 3 bytes, "語" = 3 bytes
# Plus 2 bytes for quotes = 11 bytes total
let ast_jp = ast --json '"日本語"' | get block | from json
let base_jp = $ast_jp.span.start
let span_jp = $ast_jp.pipelines.0.elements.0.expr.span
let length_jp = $span_jp.end - $span_jp.start
{relative_start: ($span_jp.start - $base_jp), relative_end: ($span_jp.end - $base_jp), byte_length: $length_jp}
| to nuon
| print $in
# => {relative_start: 0, relative_end: 11, byte_length: 11}

# Demonstrate correct extraction using bytes (not str substring)
let source_jp = '"日本語"'
$source_jp | encode utf8 | bytes at 0..<11 | decode utf8 | print $in
# => "日本語"

# str substring uses byte positions, so it works with spans directly
# but can produce invalid UTF-8 if you split mid-character
$source_jp | str substring 0..<11 | print $in
# => "日本語"

# Character count vs byte count
# Note: str length defaults to bytes in modern Nushell; use --grapheme-clusters for chars
let char_count = ('"日本語"' | str length --grapheme-clusters)
let byte_count = ('"日本語"' | encode utf8 | bytes length)
{characters: $char_count, bytes: $byte_count} | to nuon | print $in
# => {characters: 5, bytes: 11}

# ============================================================
# MULTI-TOKEN EXPRESSION SPANS
# ============================================================

# --- Arithmetic expression `1 + 2` ---

'1 + 2' | print $in
# => 1 + 2

# Each token has its own span within the BinaryOp
let ast_arith = ast --json '1 + 2' | get block | from json
let base_arith = $ast_arith.span.start
let ops = $ast_arith.pipelines.0.elements.0.expr.expr.BinaryOp

# Show relative spans for each operand and operator
$ops
| each {|e| {
    start: ($e.span.start - $base_arith),
    end: ($e.span.end - $base_arith),
    length: ($e.span.end - $e.span.start)
}}
| to nuon
| print $in
# => [[start, end, length]; [0, 1, 1], [2, 3, 1], [4, 5, 1]]

# Position map:
# "1 + 2"
#  0 2 4   <- start positions
#  1 3 5   <- end positions
# Note: there are GAPS at positions 1-2 and 3-4 (spaces)

# Extract each token using its span
let source_arith = '1 + 2'
$ops
| each {|e|
    let rel_start = $e.span.start - $base_arith
    let rel_end = $e.span.end - $base_arith
    {
        text: ($source_arith | str substring $rel_start..<$rel_end),
        span: {start: $rel_start, end: $rel_end}
    }
}
| to nuon
| print $in
# => [[text, span]; [1, {start: 0, end: 1}], [+, {start: 2, end: 3}], [2, {start: 4, end: 5}]]

# ============================================================
# NESTED EXPRESSION SPANS
# ============================================================

# --- Parenthesized expression `(1 + 2) * 3` ---

'(1 + 2) * 3' | print $in
# => (1 + 2) * 3

let ast_nested = ast --json '(1 + 2) * 3' | get block | from json
let base_nested = $ast_nested.span.start

# The outer expression is BinaryOp: [(1+2), *, 3]
let outer_ops = $ast_nested.pipelines.0.elements.0.expr.expr.BinaryOp

# Outer spans: the parenthesized group, operator, and final operand
$outer_ops
| each {|e| {
    start: ($e.span.start - $base_nested),
    end: ($e.span.end - $base_nested)
}}
| to nuon
| print $in
# => [[start, end]; [0, 7], [8, 9], [10, 11]]

# Position map for outer expression:
# "(1 + 2) * 3"
#  0       8 10   <- start positions
#  7       9 11   <- end positions
# The left operand span (0-7) encompasses the entire "(1 + 2)"

# Note: In `ast --json`, subexpressions are represented by block IDs,
# not inline AST structures. The Subexpression field contains just an ID.
$outer_ops.0.expr.FullCellPath.head.expr | columns | to nuon | print $in
# => [Subexpression]

# To access inner expression spans, use the ir_block.spans field
# which contains all spans including nested expressions
let ir_spans = $ast_nested.ir_block.spans

# Calculate relative positions for all IR spans
$ir_spans
| each {|s| {start: ($s.start - $base_nested), end: ($s.end - $base_nested)}}
| uniq
| sort-by start
| to nuon
| print $in
# => [[start, end]; [1, 2], [3, 4], [5, 6], [1, 6], [8, 9], [10, 11], [0, 11]]

# IR spans include:
# - Individual operands: 1 at [1,2], + at [3,4], 2 at [5,6], * at [8,9], 3 at [10,11]
# - Inner subexpression result: [1,6] for "1 + 2"
# - Full expression: [0,11] for "(1 + 2) * 3"

# Verify parent span (0-7) encompasses the inner content spans (1-6)
let parent_start = $outer_ops.0.span.start - $base_nested
let parent_end = $outer_ops.0.span.end - $base_nested
{
    parent_span: {start: $parent_start, end: $parent_end},
    note: "Span 0-7 covers '(1 + 2)' including parentheses"
}
| to nuon
| print $in
# => {parent_span: {start: 0, end: 7}, note: "Span 0-7 covers '(1 + 2)' including parentheses"}

# ============================================================
# PIPELINE SPANS
# ============================================================

# --- Two-stage pipeline `ls | length` ---

'ls | length' | print $in
# => ls | length

let ast_pipe = ast --json 'ls | length' | get block | from json
let base_pipe = $ast_pipe.span.start
let elements = $ast_pipe.pipelines.0.elements

# Each pipeline element has an expr with its own span
$elements
| each {|e| {
    expr_start: ($e.expr.span.start - $base_pipe),
    expr_end: ($e.expr.span.end - $base_pipe),
    pipe: (if $e.pipe != null {
        {start: ($e.pipe.start - $base_pipe), end: ($e.pipe.end - $base_pipe)}
    } else { null })
}}
| to nuon
| print $in
# => [[expr_start, expr_end, pipe]; [0, 2, null], [5, 11, {start: 3, end: 4}]]

# Position map:
# "ls | length"
#  0  3 5          <- key positions
#  2  4 11         <- end positions
# ls: 0-2, pipe: 3-4, length: 5-11
# Note the gap at position 2-3 (space before pipe) and 4-5 (space after pipe)

# Extract source text for each element
let source_pipe = 'ls | length'
$elements
| each {|e|
    let rel_start = $e.expr.span.start - $base_pipe
    let rel_end = $e.expr.span.end - $base_pipe
    $source_pipe | str substring $rel_start..<$rel_end
}
| to nuon
| print $in
# => [ls, length]

# ============================================================
# STRING WITH ESCAPE SEQUENCES
# ============================================================

# --- String `"hello\nworld"` ---

'"hello\nworld"' | print $in
# => "hello\nworld"

# The escape sequence \n is 2 bytes in source, but 1 byte when evaluated
let ast_esc = ast --json '"hello\nworld"' | get block | from json
let base_esc = $ast_esc.span.start
let span_esc = $ast_esc.pipelines.0.elements.0.expr.span

# Source byte length (includes \n as 2 chars)
let source_esc = '"hello\nworld"'
let source_bytes = $source_esc | encode utf8 | bytes length
let span_length = $span_esc.end - $span_esc.start

{
    source_byte_length: $source_bytes,
    span_byte_length: $span_length,
    relative_span: {start: ($span_esc.start - $base_esc), end: ($span_esc.end - $base_esc)}
}
| to nuon
| print $in
# => {source_byte_length: 14, span_byte_length: 14, relative_span: {start: 0, end: 14}}

# The span reflects the SOURCE representation (14 bytes with escape)
# not the evaluated string value (12 bytes with actual newline)
let evaluated_length = ("hello\nworld" | encode utf8 | bytes length)
{source_representation: $span_length, evaluated_value: $evaluated_length}
| to nuon
| print $in
# => {source_representation: 14, evaluated_value: 11}

# ============================================================
# COMMAND WITH ARGUMENTS
# ============================================================

# --- Command `echo hello world` ---

'echo hello world' | print $in
# => echo hello world

let ast_cmd = ast --json 'echo hello world' | get block | from json
let base_cmd = $ast_cmd.span.start
let call = $ast_cmd.pipelines.0.elements.0.expr.expr.Call

# Head span (command name)
let head_span = {
    start: ($call.head.start - $base_cmd),
    end: ($call.head.end - $base_cmd)
}

# Argument spans
let arg_spans = $call.arguments
| each {|arg|
    let span = $arg.Positional.span
    {start: ($span.start - $base_cmd), end: ($span.end - $base_cmd)}
}

{head: $head_span, arguments: $arg_spans}
| to nuon
| print $in
# => {head: {start: 0, end: 4}, arguments: [[start, end]; [5, 10], [11, 16]]}

# Position map:
# "echo hello world"
#  0    5     11       <- start positions
#  4    10    16       <- end positions
# echo: 0-4, hello: 5-10, world: 11-16

# Extract each component using spans
let source_cmd = 'echo hello world'
{
    command: ($source_cmd | str substring $head_span.start..<$head_span.end),
    args: ($arg_spans | each {|s| $source_cmd | str substring $s.start..<$s.end})
}
| to nuon
| print $in
# => {command: echo, args: [hello, world]}

# ============================================================
# GAPS AND ADJACENCY IN SPANS
# ============================================================

# --- List elements with varying whitespace ---

# Tight list `[1,2]` - minimal gaps (just comma)
'[1,2]' | print $in
# => [1,2]

let ast_tight = ast --json '[1,2]' | get block | from json
let base_tight = $ast_tight.span.start
let items_tight = $ast_tight.pipelines.0.elements.0.expr.expr.FullCellPath.head.expr.List

let spans_tight = $items_tight
| each {|e| {start: ($e.Item.span.start - $base_tight), end: ($e.Item.span.end - $base_tight)}}

# Check for gaps between consecutive spans
let gaps_tight = 0..(($spans_tight | length) - 2)
| each {|i| $spans_tight | get ($i + 1) | get start | $in - ($spans_tight | get $i | get end)}

{spans: $spans_tight, gaps: $gaps_tight}
| to nuon
| print $in
# => {spans: [[start, end]; [1, 2], [3, 4]], gaps: [1]}

# Position map for [1,2]:
# "[1,2]"
#  01234   <- positions
# Item 1: span [1,2], Item 2: span [3,4]
# Gap of 1 byte between them (the comma at position 2)

# Spaced list `[1, 2]` - includes space after comma
'[1, 2]' | print $in
# => [1, 2]

let ast_spaced = ast --json '[1, 2]' | get block | from json
let base_spaced = $ast_spaced.span.start
let items_spaced = $ast_spaced.pipelines.0.elements.0.expr.expr.FullCellPath.head.expr.List

let spans_spaced = $items_spaced
| each {|e| {start: ($e.Item.span.start - $base_spaced), end: ($e.Item.span.end - $base_spaced)}}

let gaps_spaced = 0..(($spans_spaced | length) - 2)
| each {|i| $spans_spaced | get ($i + 1) | get start | $in - ($spans_spaced | get $i | get end)}

{spans: $spans_spaced, gaps: $gaps_spaced}
| to nuon
| print $in
# => {spans: [[start, end]; [1, 2], [4, 5]], gaps: [2]}

# Position map for [1, 2]:
# "[1, 2]"
#  012345   <- positions
# Item 1: span [1,2], Item 2: span [4,5]
# Gap of 2 bytes between them (comma + space at positions 2-3)

# Gaps represent non-token bytes between token spans
# Gap value = bytes for separators, whitespace, punctuation

# ============================================================
# PRACTICAL UTILITY: Extract Source Text from Span
# ============================================================

# This helper pattern extracts source text from any AST span:
#
# def extract-source [source: string, span: record, base: int] {
#     let rel_start = $span.start - $base
#     let rel_end = $span.end - $base
#     # Use bytes for UTF-8 safety:
#     $source | encode utf8 | bytes at $rel_start..<$rel_end | decode utf8
# }

# Example: extract all tokens from a complex expression
let complex = 'let x = (1 + 2) * 3'
$complex | print $in
# => let x = (1 + 2) * 3

# Using ast --flatten for comprehensive token extraction
# Note: ast --flatten returns {content, shape, span} where span is a record
let tokens = ast --flatten $complex
let base = $tokens.0.span.start

$tokens
| each {|t|
    let rel_start = $t.span.start - $base
    let rel_end = $t.span.end - $base
    {
        content: $t.content,
        relative_span: {start: $rel_start, end: $rel_end},
        length: ($rel_end - $rel_start)
    }
}
| to nuon
| print $in
# => [[content, relative_span, length]; [let, {start: 0, end: 3}, 3], [x, {start: 4, end: 5}, 1], ["(", {start: 8, end: 9}, 1], ["1", {start: 9, end: 10}, 1], [+, {start: 11, end: 12}, 1], ["2", {start: 13, end: 14}, 1], [")", {start: 14, end: 15}, 1], [*, {start: 16, end: 17}, 1], ["3", {start: 18, end: 19}, 1]]

# Note: `=` is not a separate token in ast --flatten for let statements
# Position map shows gaps where syntax elements aren't tokenized:
# "let x = (1 + 2) * 3"
#  ^^^     ^^ ^ ^^ ^^
#  let  x  (1 + 2) * 3   <- tokens
#      5-8 gap (space, equals, space)

