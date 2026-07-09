![dotnu](https://github.com/user-attachments/assets/4fb74e46-f75b-4155-8e61-8ff75db66117)

<h1 align="center">dotnu - tools for Nushell module developers 🛠️</h1>

<p align="center"><em>(A good companion for <a href="https://github.com/nushell-prophet/numd">numd</a>)</em></p>

<p align="center">dotnu augments Nushell with helpers for literate programming, dependency analysis, and script profiling.</p>

## Video demo

<a href="https://youtu.be/-C7_dfLXXrE">
  <img src="https://github.com/user-attachments/assets/fdd07bfc-7d77-4dca-8a1c-3e27ac3063f9" alt="dotnu demo" width="100"/>
</a>

## Quickstart

### `git`

```nushell no-run
git clone https://github.com/nushell-prophet/dotnu; cd dotnu
use dotnu
```

### [`nupm`](https://github.com/nushell/nupm)

```nushell no-run
nupm install https://github.com/nushell-prophet/dotnu --git
# if nupm modules are not in  `NU_LIB_DIRS`:
$env.NU_LIB_DIRS ++= [ ($env.NUPM_HOME | path join "modules") ]

use dotnu
```

## Embeds — Literate Programming

`dotnu` lets you write **literate Nushell**: ordinary Nushell scripts that include the real command output right after each pipeline ending in `| print $in`.

The `| print $in` suffix acts as a simple `print` in native Nushell and as a capture marker for dotnu, so scripts remain valid and functional even when run without loading the `dotnu` module.

<!-- numd-gen-start: use numd; use dotnu; numd doc 'dotnu embeds-update' -->
### `dotnu embeds-update`

Inserts captured output back into the script at capture points

The main command of the embeds family: takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

Run it on a file path (e.g., `dotnu embeds-update dotnu-capture.nu`) or pipe a script into it (e.g., `"ls | print $in" | dotnu embeds-update`).

```nushell no-run
dotnu embeds-update (file)    # `string -> nothing`, `string -> string`, `nothing -> string`, `nothing -> nothing`
```

**Parameters:**

- `file?: path`

**Flags:**

- `--echo` — output updates to stdout
<!-- numd-gen-end -->

### Helper commands

While it is easy to write scripts in an editor, there are several convenience helper commands that facilitate populating script files from the terminal.

#### `dotnu embed-add`

<!-- numd-gen-start: numd doc 'dotnu embed-add' --no-header -->
Embed stdin together with its command into the file

Captures only the pipeline you run it on — useful for fine-grained examples.

```nushell no-run
dotnu embed-add
```

**Flags:**

- `--capture-path: path` — capture file to append to; remembered for later calls in the session
- `--pipe-further (-p)` — output input further to the pipeline
- `--published` — output the published representation into terminal
- `--dry-run`
<!-- numd-gen-end -->

#### `dotnu embeds-remove`

<!-- numd-gen-start: numd doc 'dotnu embeds-remove' --no-header -->
Removes annotation lines starting with "# => " from the script

```nushell no-run
dotnu embeds-remove
```
<!-- numd-gen-end -->

## Expand Code — Generate Code from Directives

`dotnu expand-code` is the inverse of `embeds-update`. Where `embeds-update` runs code and writes its *output* back as `# =>` comments, `expand-code` runs a pipeline written *inside* a comment and writes that pipeline's text result back as **real code lines**.

A directive is a line beginning with `#**`; everything after the marker is a Nushell pipeline that must return text. Each line of that text becomes one generated code line, inserted right after the directive and up to a `#**end` marker on its own line.

Start with an empty block — here in a module's `mod.nu`, just the directive and its end marker:

```nushell no-run
#** ls *.nu | where name != 'mod.nu' | get name | each { $"export use ($in) *" } | to text
#**end
```

Running `dotnu expand-code mod.nu` fills the block, re-exporting every sibling command file:

```nushell no-run
#** ls *.nu | where name != 'mod.nu' | get name | each { $"export use ($in) *" } | to text
export use config.nu *
export use greet.nu *
export use history.nu *
#**end
```

The directive and the `#**end` marker are never modified, so a re-run replaces only the lines between them — refreshing the generated code whenever the inputs change (here, whenever you add or remove a command file). Relative paths in the pipeline resolve against the file's own directory, so `ls *.nu` sees the module's own files.

Like `embeds-update`, you can run it on a file path (`dotnu expand-code file.nu`) or pipe a script in and get the result back (`$script | dotnu expand-code`). Pass `--echo` to print the result instead of saving to the file.

## Dependency Analysis

<!-- numd-gen-start: numd doc 'dotnu dependencies' -->
### `dotnu dependencies`

Check .nu module files to determine which commands depend on other commands.

```nushell no-run
dotnu dependencies ...(paths)
```

**Parameters:**

- `...paths: path` — paths to nushell module files

**Flags:**

- `--keep-builtins` — keep builtin commands in the result page
- `--definitions-only` — output only commands' names definitions

**Examples:**

Analyze command dependencies in a module

```nushell no-run
dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
# => ╭───┬──────────┬────────────────────┬──────────┬──────╮
# => │ # │  caller  │ filename_of_caller │  callee  │ step │
# => ├───┼──────────┼────────────────────┼──────────┼──────┤
# => │ 0 │ question │ ask.nu             │          │    0 │
# => │ 1 │ hello    │ hello.nu           │          │    0 │
# => │ 2 │ say      │ mod.nu             │ hello    │    0 │
# => │ 3 │ say      │ mod.nu             │ hi       │    0 │
# => │ 4 │ say      │ mod.nu             │ question │    0 │
# => │ 5 │ hi       │ mod.nu             │          │    0 │
# => │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
# => ╰───┴──────────┴────────────────────┴──────────┴──────╯
```
<!-- numd-gen-end -->

<!-- numd-gen-start: numd doc 'dotnu filter-commands-with-no-tests' -->
### `dotnu filter-commands-with-no-tests`

Filter commands after `dotnu dependencies` that aren't used by any test command.
Test commands are detected by: name contains 'test' OR file matches 'test*.nu'

```nushell no-run
dotnu filter-commands-with-no-tests
```

**Examples:**

Find commands not covered by tests

```nushell no-run
dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
# => ╭───┬──────────┬────────────────────╮
# => │ # │  caller  │ filename_of_caller │
# => ├───┼──────────┼────────────────────┤
# => │ 0 │ question │ ask.nu             │
# => │ 1 │ hello    │ hello.nu           │
# => │ 2 │ say      │ mod.nu             │
# => ╰───┴──────────┴────────────────────╯
```
<!-- numd-gen-end -->

## Script Profiling

<!-- numd-gen-start: numd doc 'dotnu set-x' -->
### `dotnu set-x`

Open a regular .nu script. Divide it into blocks by "\n\n". Generate a new script
that will print the code of each block before executing it, and print the timings of each block's execution.

```nushell no-run
dotnu set-x <file>
```

**Parameters:**

- `file: path` — path to `.nu` file

**Flags:**

- `--regex: string` — regex to split on blocks (default: '\n+\n' - blank lines)
- `--echo` — output script to terminal
- `--quiet` — don't print any messages

**Examples:**

Generate script with timing instrumentation

```nushell no-run
set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text
# => mut $prev_ts = ( date now )
# => print ("> sleep 0.5sec" | nu-highlight)
# => sleep 0.5sec
```
<!-- numd-gen-end -->

Example with a simple script:

```nushell
let $filename = [tests assets set-x-demo.nu] | path join
open $filename | lines | table -i false
# => ╭──────────────╮
# => │ sleep 0.5sec │
# => │              │
# => │ sleep 0.7sec │
# => │              │
# => │ sleep 0.8sec │
# => ╰──────────────╯
```

```nushell
dotnu set-x $filename --echo | lines | table -i false
# => ╭─────────────────────────────────────────────────────────────────────────────╮
# => │ mut $prev_ts = ( date now )                                                 │
# => │ print ("> sleep 0.5sec" | nu-highlight)                                     │
# => │ sleep 0.5sec                                                                │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date   │
# => │ now);                                                                       │
# => │                                                                             │
# => │                                                                             │
# => │ print ("> sleep 0.7sec" | nu-highlight)                                     │
# => │ sleep 0.7sec                                                                │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date   │
# => │ now);                                                                       │
# => │                                                                             │
# => │                                                                             │
# => │ print ("> sleep 0.8sec" | nu-highlight)                                     │
# => │ sleep 0.8sec                                                                │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date   │
# => │ now);                                                                       │
# => │                                                                             │
# => │                                                                             │
# => ╰─────────────────────────────────────────────────────────────────────────────╯
```

## Utilities

<!-- numd-gen-start: numd doc 'dotnu generate-numd' -->
### `dotnu generate-numd`

Generate `.numd` from `.nu` divided into blocks by "\n\n"

Pipe a `.nu` script into this command to convert it into `.numd` format (markdown with code blocks).

```nushell no-run
dotnu generate-numd
```
<!-- numd-gen-end -->

```nushell
"sleep 0.5sec\n\nsleep 0.7sec" | dotnu generate-numd
# => ```nu
# => sleep 0.5sec
# => ```
# =>
# => ```nu
# => sleep 0.7sec
# => ```
# =>
```

### `dotnu extract-module-command`

Extract a command with its whole dependency cascade from a module into one self-contained script. The module is imported into a clean `nu -n` process and command bodies are dumped via `view source`, so Nushell itself resolves `export use` chains, submodules and `main` renaming. Private dependencies are embedded as plain `def`, definitions come in dependency order, and imports of external modules (`std` etc.) are reproduced as `use` lines.

Importing a module runs its `export-env` blocks, so the command refuses modules containing `export-env` unless you pass `--allow-export-env` after inspecting them.

```nushell
dotnu extract-module-command tests/assets/module-embed greet
# => use std/assert
# =>
# => export def greet-word [] {
# =>     assert true
# =>     'hello'
# => }
# =>
# => def subject [] { 'world' }
# =>
# => export def greet [] { $"(greet-word) (subject)!" }
```

Pass `--vars` (or a non-empty `--set-vars`) to turn the target into a debug scaffold instead: its parameters become `let` bindings you can edit, and its body is unwrapped to the top level, so sourcing the script runs the body with the variables in scope. The dependencies stay embedded as `def`. With `--output`, values you edit in the saved file are kept on re-extraction unless you pass `--clear-vars`.

```nushell
dotnu extract-module-command tests/assets/module-embed greet-loud --vars
# => use std/assert
# =>
# => export def greet-word [] {
# =>     assert true
# =>     'hello'
# => }
# =>
# => def subject [] { 'world' }
# =>
# => # def greet-loud [ --upper ] {
# => #dotnu-vars-start
# => let $upper = false
# => #dotnu-vars-end
# =>     let msg = $"(greet-word) (subject)!"
# =>     if $upper { $msg | str upcase } else { $msg }
```

### `dotnu list-module-exports`

List all exported definitions from a module file. Finds commands from `export def` and `export use` patterns, including bare and glob re-exports (resolved by reading the referenced submodule).

```nushell
dotnu list-module-exports dotnu/mod.nu | first 5
# => ╭───┬─────────────────╮
# => │ 0 │ dependencies    │
# => │ 1 │ embed-add       │
# => │ 2 │ embeds-remove   │
# => │ 3 │ embeds-update   │
# => │ 4 │ examples-update │
# => ╰───┴─────────────────╯
```

### `dotnu list-module-interface`

List module's callable interface - the `main` and `main subcommand` patterns that become available when you `use` the module.

```nushell
dotnu list-module-interface tests/assets/b/example-mod1.nu
# => ╭───┬──────╮
# => │ 0 │ main │
# => ╰───┴──────╯
```

<!-- numd-gen-start: numd doc 'dotnu module-commands-code-to-record' -->
### `dotnu module-commands-code-to-record`

Extract all commands from a module as a record of {command_name: source_code}

```nushell no-run
dotnu module-commands-code-to-record <module_path>
```

**Parameters:**

- `module_path: path` — path to a Nushell module file
<!-- numd-gen-end -->
