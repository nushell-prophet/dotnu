# Add more AST behavior test cases

## Goal
Document additional AST parsing behaviors to ensure `ast-complete` and AST-based parsing remain robust across Nushell versions.

## Existing test cases
- `tests/ast-cases/semicolon-stripping.nu` - `;` and `=` stripping
- `tests/ast-cases/block-boundaries.nu` - shape_block vs shape_closure
- `tests/ast-cases/attribute-detection.nu` - @example, @test parsing
- `tests/ast-cases/def-parsing.nu` - def/export def tokenization
- `tests/ast-cases/ast-complete.nu` - gap-filling verification

## Additional cases to document

### String literals
- [ ] Single vs double quotes
- [ ] Interpolated strings `$"..."`
- [ ] Raw strings `r#"..."#`
- [ ] Multiline strings
- [ ] Escape sequences

### Operators
- [ ] Arithmetic operators (+, -, *, /)
- [ ] Comparison operators (==, !=, <, >)
- [ ] Logical operators (and, or, not)
- [ ] Range operator (..)
- [ ] Pipeline operators (| , |>)

### Variables
- [ ] Variable declaration (let, mut)
- [ ] Variable reference ($var)
- [ ] Environment variables ($env.VAR)
- [ ] Special variables ($in, $it, $nu)

### Complex structures
- [ ] Nested closures
- [ ] Match expressions
- [ ] Try/catch blocks
- [ ] Loop constructs (for, while, loop)

### Edge cases
- [ ] Unicode identifiers
- [ ] Very long lines
- [ ] Deeply nested structures
- [ ] Empty blocks `{}`

## Tasks
- [ ] Create string-literals.nu test case
- [ ] Create operators.nu test case
- [ ] Create variables.nu test case
- [ ] Create complex-structures.nu test case
- [ ] Run embeds-update on all new files
- [ ] Commit each test case

## Related files
- `tests/ast-cases/` - test case directory
- `dotnu/commands.nu` - ast-complete command
