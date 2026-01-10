# AST Behavior: Variables
#
# How variables are tokenized in `ast --flatten`:
# - Declaration (let, mut): shape_internalcall
# - Variable name in declaration: shape_vardecl
# - Variable reference ($var): shape_variable
# - Environment variables ($env.X): shape_variable
# - Special variables ($in, $nu): shape_variable
#
# Note: The `=` in variable assignment is stripped (not tokenized).

source ../../dotnu/commands.nu

version | select version | print $in
# => ╭─────────┬─────────╮
# => │ version │ 0.109.1 │
# => ╰─────────┴─────────╯


# --- Variable declaration with let ---

'let x = 1' | print $in
# => let x = 1


ast --flatten 'let x = 1' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ 1       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯


# Note: `=` is at position 6-7 but not tokenized
ast --flatten 'let x = 1' | flatten span | select content start end | print $in
# => ╭───┬─────────┬───────┬─────╮
# => │ # │ content │ start │ end │
# => ├───┼─────────┼───────┼─────┤
# => │ 0 │ let     │     0 │   3 │
# => │ 1 │ x       │     4 │   5 │
# => │ 2 │ 1       │     8 │   9 │
# => ╰───┴─────────┴───────┴─────╯


# --- Variable declaration with mut ---

'mut y = 2' | print $in
# => mut y = 2


ast --flatten 'mut y = 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ mut     │ shape_internalcall │
# => │ 1 │ y       │ shape_vardecl      │
# => │ 2 │ 2       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯


# --- Variable reference ---

'$x' | print $in
# => $x


ast --flatten '$x' | select content shape | print $in
# => ╭───┬─────────┬───────────────╮
# => │ # │ content │     shape     │
# => ├───┼─────────┼───────────────┤
# => │ 0 │ $x      │ shape_garbage │
# => ╰───┴─────────┴───────────────╯


# --- Multiple variable references ---

'$x + $y' | print $in
# => $x + $y


ast --flatten '$x + $y' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ $x      │ shape_garbage  │
# => │ 1 │ +       │ shape_operator │
# => │ 2 │ $y      │ shape_garbage  │
# => ╰───┴─────────┴────────────────╯


# --- Environment variables ---

'$env.HOME' | print $in
# => $env.HOME


ast --flatten '$env.HOME' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ $env    │ shape_variable │
# => │ 1 │ HOME    │ shape_string   │
# => ╰───┴─────────┴────────────────╯


'$env.PATH' | print $in
# => $env.PATH


ast --flatten '$env.PATH' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ $env    │ shape_variable │
# => │ 1 │ PATH    │ shape_string   │
# => ╰───┴─────────┴────────────────╯


# --- Special variable: $in ---

'$in' | print $in
# => $in


ast --flatten '$in' | select content shape | print $in
# => ╭───┬─────────┬────────────────╮
# => │ # │ content │     shape      │
# => ├───┼─────────┼────────────────┤
# => │ 0 │ $in     │ shape_variable │
# => ╰───┴─────────┴────────────────╯


# --- Special variable: $nu ---

'$nu.home-path' | print $in
# => $nu.home-path


ast --flatten '$nu.home-path' | select content shape | print $in
# => ╭───┬───────────┬────────────────╮
# => │ # │  content  │     shape      │
# => ├───┼───────────┼────────────────┤
# => │ 0 │ $nu       │ shape_variable │
# => │ 1 │ home-path │ shape_string   │
# => ╰───┴───────────┴────────────────╯


# --- Variable with type annotation ---

'let x: int = 1' | print $in
# => let x: int = 1


ast --flatten 'let x: int = 1' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ 1       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯


# --- Variable shadowing ---

'let x = 1; let x = 2' | print $in
# => let x = 1; let x = 2


ast --flatten 'let x = 1; let x = 2' | select content shape | print $in
# => ╭───┬─────────┬────────────────────╮
# => │ # │ content │       shape        │
# => ├───┼─────────┼────────────────────┤
# => │ 0 │ let     │ shape_internalcall │
# => │ 1 │ x       │ shape_vardecl      │
# => │ 2 │ 1       │ shape_int          │
# => │ 3 │ let     │ shape_internalcall │
# => │ 4 │ x       │ shape_vardecl      │
# => │ 5 │ 2       │ shape_int          │
# => ╰───┴─────────┴────────────────────╯

