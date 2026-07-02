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

### `dotnu embeds-update`

The main command. It takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

You can run it on a file path (e.g., `dotnu embeds-update dotnu-capture.nu`) or pipe a script into it (e.g., `"ls | print $in" | dotnu embeds-update`).

```nushell
use dotnu
dotnu embeds-update --help
# => Inserts captured output back into the script at capture points
# =>
# => Usage:
# =>   > embeds-update {flags} (file)
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --echo: output updates to stdout
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   file <path>:  (optional)
# =>
# => Input/output types:
# =>   ╭───┬─────────┬─────────╮
# =>   │ # │  input  │ output  │
# =>   ├───┼─────────┼─────────┤
# =>   │ 0 │ string  │ nothing │
# =>   │ 1 │ string  │ string  │
# =>   │ 2 │ nothing │ string  │
# =>   │ 3 │ nothing │ nothing │
# =>   ╰───┴─────────┴─────────╯
# =>
```

### Helper commands

While it is easy to write scripts in an editor, there are several convenience helper commands that facilitate populating script files from the terminal.

#### `dotnu embeds-setup`

Define or change the capture file (add `--auto-commit` to auto-commit snapshots).

```nushell
dotnu embeds-setup --help
# => Set environment variables to operate with embeds
# =>
# => Usage:
# =>   > embeds-setup {flags} (path)
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --auto-commit
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   path <path>:  (optional)
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

#### `dotnu embed-add`

Capture only the pipeline you run it on; useful for fine-grained examples.

```nushell
dotnu embed-add --help
# => Embed stdin together with its command into the file
# =>
# => Usage:
# =>   > embed-add {flags}
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   -p, --pipe-further: output input further to the pipeline
# =>   --published: output the published representation into terminal
# =>   --dry_run: todo: --
# =>
# => Command Type:
# =>   > custom
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

#### `dotnu embeds-remove`

Strip all captured output, leaving clean code.

```nushell
dotnu embeds-remove --help
# => Removes annotation lines starting with "# => " from the script
# =>
# => Usage:
# =>   > embeds-remove
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Command Type:
# =>   > custom
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

## Expand Code — Generate Code from Directives

`dotnu expand-code` is the inverse of `embeds-update`. Where `embeds-update` runs code and writes its *output* back as `# =>` comments, `expand-code` runs a pipeline written *inside* a comment and writes that pipeline's text result back as **real code lines**.

A directive is a line beginning with `#**`; everything after the marker is a Nushell pipeline that must return text. Each line of that text becomes one generated code line, inserted right after the directive and up to a `#**end` marker on its own line.

Start with an empty block — just the directive and its end marker:

```nushell
#** ls todo/ | get name | each { $"open -r ($in)" } | to text
#**end
```

Running `dotnu expand-code file.nu` fills the block:

```nushell
#** ls todo/ | get name | each { $"open -r ($in)" } | to text
open -r todo/20251216-022041.md
open -r todo/20260630-090000.md
#**end
```

The directive and the `#**end` marker are never modified, so a re-run replaces only the lines between them — refreshing the generated code whenever the inputs change (here, whenever `todo/` changes). Relative paths in the pipeline resolve against the file's own directory.

Like `embeds-update`, you can run it on a file path (`dotnu expand-code file.nu`) or pipe a script in and get the result back (`$script | dotnu expand-code`). Pass `--echo` to print the result instead of saving to the file.

## Dependency Analysis

### `dotnu dependencies`

```nushell
dotnu dependencies --help
# => Check .nu module files to determine which commands depend on other commands.
# =>
# => Usage:
# =>   > dependencies {flags} ...(paths)
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --keep-builtins: keep builtin commands in the result page
# =>   --definitions-only: output only commands' names definitions
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   ...paths <path>: paths to nushell module files
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
# => Examples:
# =>   Analyze command dependencies in a module
# =>   > dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
# =>   ╭───┬──────────┬────────────────────┬──────────┬──────╮
# =>   │ # │  caller  │ filename_of_caller │  callee  │ step │
# =>   ├───┼──────────┼────────────────────┼──────────┼──────┤
# =>   │ 0 │ question │ ask.nu             │          │    0 │
# =>   │ 1 │ hello    │ hello.nu           │          │    0 │
# =>   │ 2 │ say      │ mod.nu             │ hello    │    0 │
# =>   │ 3 │ say      │ mod.nu             │ hi       │    0 │
# =>   │ 4 │ say      │ mod.nu             │ question │    0 │
# =>   │ 5 │ hi       │ mod.nu             │          │    0 │
# =>   │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
# =>   ╰───┴──────────┴────────────────────┴──────────┴──────╯
# =>
```

### `dotnu filter-commands-with-no-tests`

```nushell
dotnu filter-commands-with-no-tests --help
# => Filter commands after `dotnu dependencies` that aren't used by any test command.
# => Test commands are detected by: name contains 'test' OR file matches 'test*.nu'
# =>
# => Usage:
# =>   > filter-commands-with-no-tests
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Command Type:
# =>   > custom
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
# => Examples:
# =>   Find commands not covered by tests
# =>   > dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
# =>   ╭───┬──────────┬────────────────────╮
# =>   │ # │  caller  │ filename_of_caller │
# =>   ├───┼──────────┼────────────────────┤
# =>   │ 0 │ question │ ask.nu             │
# =>   │ 1 │ hello    │ hello.nu           │
# =>   │ 2 │ say      │ mod.nu             │
# =>   ╰───┴──────────┴────────────────────╯
# =>
```

## Script Profiling

### `dotnu set-x`

Divide a script into blocks and generate a new script that prints each block before executing it, along with timing information.

```nushell
dotnu set-x --help
# => Open a regular .nu script. Divide it into blocks by "\n\n". Generate a new script
# => that will print the code of each block before executing it, and print the timings of each block's execution.
# =>
# => Usage:
# =>   > set-x {flags} <file>
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --regex <string>: regex to split on blocks (default: '\n+\n' - blank lines)
# =>   --echo: output script to terminal
# =>   --quiet: don't print any messages
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   file <path>: path to `.nu` file
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
# => Examples:
# =>   Generate script with timing instrumentation
# =>   > set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text
# =>   mut $prev_ts = ( date now )
# =>   print ("> sleep 0.5sec" | nu-highlight)
# =>   sleep 0.5sec
# =>
```

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

### `dotnu generate-numd`

Pipe a `.nu` script into this command to convert it into `.numd` format (markdown with code blocks).

```nushell
dotnu generate-numd --help
# => Generate `.numd` from `.nu` divided into blocks by "\n\n"
# =>
# => Usage:
# =>   > generate-numd
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Command Type:
# =>   > custom
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

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

### `dotnu extract-command-code`

Extract a command from a module, resolve its parameter defaults, and create a standalone script you can source to get all variables in scope. Useful for debugging.

```nushell
dotnu extract-command-code --help
# => Extract command code from a module and save it as a `.nu` file that can be sourced.
# => By executing this `.nu` file, you'll have all the variables in your environment for debugging or development.
# =>
# => Usage:
# =>   > extract-command-code {flags} <$module_path> <$command>
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --output <path>: a file path to save the extracted command script
# =>   --clear-vars: clear variables previously set in the extracted .nu file
# =>   --echo: output the command to the terminal
# =>   --set-vars <record>: set variables for a command (default: {})
# =>   --code-editor <string>: code is my editor of choice to open the result file (default: 'code')
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   $module_path <path>: path to a Nushell module file
# =>   $command <string>: the name of the command to extract
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

### `dotnu extract-module-command`

Extract a command with its whole dependency cascade from a module into one self-contained script. Unlike `extract-command-code` (static parsing of one file), the module is imported into a clean `nu -n` process and command bodies are dumped via `view source`, so Nushell itself resolves `export use` chains, submodules and `main` renaming. Private dependencies are embedded as plain `def`, definitions come in dependency order, and imports of external modules (`std` etc.) are reproduced as `use` lines.

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

### `dotnu list-module-exports`

List all exported definitions from a module file. Finds commands from `export def` and `export use` patterns, including bare and glob re-exports (resolved by reading the referenced submodule).

```nushell
dotnu list-module-exports dotnu/mod.nu | first 5
# => ╭───┬───────────────╮
# => │ 0 │ dependencies  │
# => │ 1 │ embed-add     │
# => │ 2 │ embeds-remove │
# => │ 3 │ embeds-setup  │
# => │ 4 │ embeds-update │
# => ╰───┴───────────────╯
```

### `dotnu list-module-interface`

List module's callable interface - the `main` and `main subcommand` patterns that become available when you `use` the module.

```nushell
dotnu list-module-interface tests/assets/b/example-mod1.nu
# => ╭───┬──────╮
# => │ 0 │ main │
# => ╰───┴──────╯
```

### `dotnu module-commands-code-to-record`

Extract all commands from a module file and return them as a record where keys are command names and values are their source code.

```nushell
dotnu module-commands-code-to-record --help
# => Extract all commands from a module as a record of {command_name: source_code}
# =>
# => Usage:
# =>   > module-commands-code-to-record <module_path>
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Command Type:
# =>   > custom
# =>
# => Parameters:
# =>   module_path <path>: path to a Nushell module file
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```
