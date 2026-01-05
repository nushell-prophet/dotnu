# AST Behavior: `ast --json` Command Calls with Arguments and Flags
#
# This file documents how command calls with various argument types are
# represented in the AST JSON output. Command calls use the `Call` expression
# type, which contains:
# - `decl_id`: integer ID of the command declaration
# - `head`: span of the command name
# - `arguments`: array of argument entries
#
# Argument types in the `arguments` array:
# - `Positional`: positional arguments (values passed by position)
# - `Named`: named parameters and flags (--name or -n)
# - `Spread`: spread arguments (...$list)
#
# Named arguments have a specific structure:
# - `Named`: array of [name_record, null, optional_value]
#   - name_record: {item: "flag-name", span: {...}}
#   - second element: always null (reserved, not currently used)
#   - optional_value: the expression if flag takes a value (null for switches)

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯

# ============================================================
# POSITIONAL ARGUMENTS
# ============================================================

# --- Single positional argument ---

'echo hello' | print $in
# => echo hello

# The argument appears as Positional with String expression
ast --json 'echo hello'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg | columns | first}
| to nuon
| print $in
# => [Positional]

# Extract the positional argument's expression
ast --json 'echo hello'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional
| select expr ty
| to nuon
| print $in
# => {expr: {String: hello}, ty: String}

# --- Multiple positional arguments ---

'echo hello world' | print $in
# => echo hello world

# Each word is a separate Positional argument
ast --json 'echo hello world'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg.Positional.expr}
| to nuon
| print $in
# => [{String: hello}, {String: world}]

# --- Positional with different types ---

'echo 42 3.14 true' | print $in
# => echo 42 3.14 true

ast --json 'echo 42 3.14 true'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| {expr: $arg.Positional.expr, ty: $arg.Positional.ty}}
| to nuon
| print $in
# => [[expr, ty]; [{Int: 42}, Int], [{Float: 3.14}, Float], [{Bool: true}, Bool]]

# ============================================================
# FLAGS (BOOLEAN SWITCHES)
# ============================================================

# --- Long flag ---

'ls --all' | print $in
# => ls --all

# Flags are Named arguments with null value (no argument value)
ast --json 'ls --all'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg | columns | first}
| to nuon
| print $in
# => [Named]

# Named structure: [name_record, null, optional_value]
# For boolean flags, optional_value is null
ast --json 'ls --all'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Named
| {name: $in.0.item, has_value: ($in.2 != null)}
| to nuon
| print $in
# => {name: all, has_value: false}

# --- Short flag ---

'ls -a' | print $in
# => ls -a

# Short flags also become Named with the full (long) name resolved
ast --json 'ls -a'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Named
| {name: $in.0.item, has_value: ($in.2 != null)}
| to nuon
| print $in
# => {name: all, has_value: false}

# --- Multiple flags ---

'ls --all --long' | print $in
# => ls --all --long

ast --json 'ls --all --long'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg.Named.0.item}
| to nuon
| print $in
# => [all, long]

# ============================================================
# NAMED PARAMETERS (FLAGS WITH VALUES)
# ============================================================

# --- Flag with string value ---

'open file.txt --raw' | print $in
# => open file.txt --raw

# First argument is positional (file.txt), second is flag (--raw)
ast --json 'open file.txt --raw'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg | columns | first}
| to nuon
| print $in
# => [Positional, Named]

# --- Full paths flag ---

'ls --full-paths' | print $in
# => ls --full-paths

ast --json 'ls --full-paths'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Named
| {name: $in.0.item, has_value: ($in.2 != null)}
| to nuon
| print $in
# => {name: full-paths, has_value: false}

# --- Flag with explicit value ---

'save --stderr bar.txt foo.txt' | print $in
# => save --stderr bar.txt foo.txt

# The --stderr flag takes a value (third element is not null)
ast --json 'save --stderr bar.txt foo.txt'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Named
| {name: $in.0.item, has_value: ($in.2 != null), value_expr: $in.2?.expr}
| to nuon
| print $in
# => {name: stderr, has_value: true, value_expr: {Filepath: [bar.txt, false]}}

# ============================================================
# MIXED ARGUMENTS
# ============================================================

# --- Positional and flags mixed ---

'ls /tmp --all --long' | print $in
# => ls /tmp --all --long

ast --json 'ls /tmp --all --long'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg|
    if ($arg | columns | first) == "Positional" {
        {type: "Positional", value: $arg.Positional.expr}
    } else {
        {type: "Named", value: $arg.Named.0.item}
    }
}
| to nuon
| print $in
# => [[type, value]; [Positional, {GlobPattern: [/tmp, false]}], [Named, all], [Named, long]]

# --- Complex command with record argument ---

'http get https://example.com --headers {Accept: "application/json"}' | print $in
# => http get https://example.com --headers {Accept: "application/json"}

# http get is a subcommand - has positional URL and named headers
ast --json 'http get https://example.com --headers {Accept: "application/json"}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg | columns | first}
| to nuon
| print $in
# => [Positional, Named]

# The --headers flag has a Record value
ast --json 'http get https://example.com --headers {Accept: "application/json"}'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.1.Named.2.expr
| columns
| first
| print $in
# => FullCellPath

# ============================================================
# SUBCOMMANDS
# ============================================================

# --- Subcommand as single Call ---

'str trim' | print $in
# => str trim

# Subcommands are a single Call, not nested - "str trim" is one command
ast --json 'str trim'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| first
| print $in
# => Call

# Verify there's only one Call (subcommand is atomic)
ast --json 'str trim'
| get block
| from json
| get pipelines.0.elements
| length
| print $in
# => 1

# The head span covers "str trim" (8 characters)
let ast_str = ast --json 'str trim' | get block | from json
let base_str = $ast_str.span.start
let head_str = $ast_str.pipelines.0.elements.0.expr.expr.Call.head
($head_str.end - $head_str.start) | print $in
# => 8

# --- Subcommand with arguments ---

'str join ","' | print $in
# => str join ","

ast --json 'str join ","'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional
| select expr ty
| to nuon
| print $in
# => {expr: {String: ","}, ty: String}

# --- Path join subcommand ---

'path join' | print $in
# => path join

# Another subcommand example - single Call
ast --json 'path join'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| first
| print $in
# => Call

# Head span covers "path join" (9 characters)
let ast_path = ast --json 'path join' | get block | from json
let base_path = $ast_path.span.start
let head_path = $ast_path.pipelines.0.elements.0.expr.expr.Call.head
($head_path.end - $head_path.start) | print $in
# => 9

# --- Subcommand with multiple arguments ---

'path join /home user documents' | print $in
# => path join /home user documents

ast --json 'path join /home user documents'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg| $arg.Positional.expr}
| to nuon
| print $in
# => [{String: /home}, {String: user}, {String: documents}]

# ============================================================
# EXTERNAL COMMANDS
# ============================================================

# --- Caret syntax for external commands ---

'^ls' | print $in
# => ^ls

# External commands use ExternalCall expression type
ast --json '^ls'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| first
| print $in
# => ExternalCall

# ExternalCall structure: [head_expr, args_array]
# The first element is the head expression, second is arguments
ast --json '^ls'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.ExternalCall.0.expr
| to nuon
| print $in
# => {GlobPattern: [ls, false]}

# --- External command with arguments ---

'^ls -la' | print $in
# => ^ls -la

# External command args are in the second element of the array
# Each arg is wrapped in Regular (or Spread for spread args)
ast --json '^ls -la'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.ExternalCall.1
| each {|arg| $arg.Regular.expr}
| to nuon
| print $in
# => [{GlobPattern: [-la, false]}]

# --- External command with multiple arguments ---

'^grep -r pattern /path' | print $in
# => ^grep -r pattern /path

ast --json '^grep -r pattern /path'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.ExternalCall.1
| each {|arg| $arg.Regular.expr}
| to nuon
| print $in
# => [[GlobPattern]; [[-r, false]], [[pattern, false]], [[/path, false]]]

# --- run-external command ---

'run-external "ls"' | print $in
# => run-external "ls"

# run-external is a regular Call (internal command that runs external)
ast --json 'run-external "ls"'
| get block
| from json
| get pipelines.0.elements.0.expr.expr
| columns
| first
| print $in
# => Call

# Its argument is the external command name (parsed as GlobPattern with quoted=true)
ast --json 'run-external "ls"'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments.0.Positional.expr
| to nuon
| print $in
# => {GlobPattern: [ls, true]}

# ============================================================
# ARGUMENT ORDER AND SPANS
# ============================================================

# --- Arguments preserve source order ---

'cp --verbose src dest' | print $in
# => cp --verbose src dest

# Arguments appear in order: flag, then positionals
ast --json 'cp --verbose src dest'
| get block
| from json
| get pipelines.0.elements.0.expr.expr.Call.arguments
| each {|arg|
    if ($arg | columns | first) == "Named" {
        "Named"
    } else {
        $arg.Positional.expr | columns | first
    }
}
| to nuon
| print $in
# => [Named, GlobPattern, GlobPattern]

# --- Relative span calculation for arguments ---

'echo hello world' | print $in
# => echo hello world

let ast_echo = ast --json 'echo hello world' | get block | from json
let base_echo = $ast_echo.span.start
let args_echo = $ast_echo.pipelines.0.elements.0.expr.expr.Call.arguments

# Get relative spans for each argument
$args_echo
| each {|arg|
    let span = $arg.Positional.span
    {start: ($span.start - $base_echo), end: ($span.end - $base_echo)}
}
| to nuon
| print $in
# => [[start, end]; [5, 10], [11, 16]]

# "echo hello world"
#      ^^^^^        span 5-10 = "hello"
#            ^^^^^ span 11-16 = "world"

# Verify by extracting source text
let source_echo = 'echo hello world'
$args_echo
| each {|arg|
    let span = $arg.Positional.span
    let rel_start = $span.start - $base_echo
    let rel_end = $span.end - $base_echo
    $source_echo | str substring $rel_start..<$rel_end
}
| to nuon
| print $in
# => [hello, world]

# ============================================================
# SUMMARY OF ARGUMENT TYPES
# ============================================================

# Arguments in Call.arguments can be:
#
# 1. Positional: {Positional: {expr, span, span_id, ty}}
#    - Regular positional arguments passed by position
#    - Order matches source order
#
# 2. Named: {Named: [name_record, null, optional_value]}
#    - name_record: {item: "flag-name", span: {...}}
#    - second element: always null (reserved)
#    - optional_value: expression or null (null for boolean flags)
#
# 3. Spread: {Spread: {expr, span, span_id, ty}}
#    - Spread arguments like ...$list
#
# External commands (^cmd) use ExternalCall with simpler args:
# - {Regular: {expr, span, span_id, ty}} for normal args
# - {Spread: {...}} for spread args
