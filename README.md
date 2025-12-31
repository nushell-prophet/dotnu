![dotnu](https://github.com/user-attachments/assets/4fb74e46-f75b-4155-8e61-8ff75db66117)

<h1 align="center"><strong>dotnu - tools for Nushell module developers 🛠️</strong></h1>

<p align="center"><em>(A good companion for <a href="https://github.com/nushell-prophet/numd">numd</a>)</em></p>

<p align="center">dotnu augments Nushell with helpers for literate programming, dependency analysis, and script profiling.</p>

## dotnu video demo

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

## Embeds — keeping examples in sync

`dotnu` lets you write **literate Nushell**: ordinary Nushell scripts that include the real command output right after each pipeline ending in `| print $in`. See the [capture example](/dotnu-capture.nu) to grasp the idea quickly.

The `| print $in` suffix acts as a simple `print` in native Nushell and as a capture marker for dotnu, so scripts remain valid and functional even when run without loading the `dotnu` module.

The main command is `dotnu embeds-update`.

`dotnu embeds-update` takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

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

### Embeds helper commands

While it is easy to write scripts in editor, there are several convenience helper commands that facilitate populating script files from terminal.

### `dotnu embeds-setup`

define or change the capture file (add `--auto-commit` to auto‑commit snapshots).

```nu
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

### `dotnu embeds-capture-start` and `dotnu embeds-capture-stop`

record every result printed in the interactive session.

```nu
dotnu embeds-capture-start --help
# => start capturing commands and their outputs into a file
# =>
# => Usage:
# =>   > embeds-capture-start (file)
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Parameters:
# =>   file <path>:  (optional, default: 'dotnu-capture.nu')
# =>
# => Input/output types:
# =>   ╭───┬─────────┬─────────╮
# =>   │ # │  input  │ output  │
# =>   ├───┼─────────┼─────────┤
# =>   │ 0 │ nothing │ nothing │
# =>   ╰───┴─────────┴─────────╯
# =>
```

### `dotnu embed-add`

capture only the pipeline you run it on; useful for fine‑grained examples.

```nu
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
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

### `dotnu embeds-remove`

strip all captured output, leaving clean code.

```nu
dotnu embeds-remove --help
# => Removes annotation lines starting with "# => " from the script
# =>
# => Usage:
# =>   > embeds-remove
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

## Commands

### dotnu dependencies

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
# =>
# =>   > dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
# =>   ╭───┬──────────┬────────────────────┬──────────┬──────╮
# =>   │ # │  caller  │ filename_of_caller │  callee  │ step │
# =>   ├───┼──────────┼────────────────────┼──────────┼──────┤
# =>   │ 0 │ hello    │ hello.nu           │          │    0 │
# =>   │ 1 │ question │ ask.nu             │          │    0 │
# =>   │ 2 │ say      │ mod.nu             │ hello    │    0 │
# =>   │ 3 │ say      │ mod.nu             │ hi       │    0 │
# =>   │ 4 │ say      │ mod.nu             │ question │    0 │
# =>   │ 5 │ hi       │ mod.nu             │          │    0 │
# =>   │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
# =>   ╰───┴──────────┴────────────────────┴──────────┴──────╯
# =>
```

### dotnu filter-commands-with-no-tests

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
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
# => Examples:
# =>
# =>   > dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
# =>   ╭───┬──────────┬────────────────────╮
# =>   │ # │  caller  │ filename_of_caller │
# =>   ├───┼──────────┼────────────────────┤
# =>   │ 0 │ hello    │ hello.nu           │
# =>   │ 1 │ question │ ask.nu             │
# =>   │ 2 │ say      │ mod.nu             │
# =>   ╰───┴──────────┴────────────────────╯
# =>
```

### dotnu set-x

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
# =>   --regex <string>: regex to use to split .nu on blocks (default: '
# => +
# => ')
# =>   --echo: output script to terminal
# =>   --quiet: don't print any messages
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
# =>
# =>   > set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text
# =>   mut $prev_ts = ( date now )
# =>   print ("> sleep 0.5sec" | nu-highlight)
# =>   sleep 0.5sec
# =>
```

`dotnu set-x` opens a regular .nu script. It divides it into blocks using the specified regex (by default, it is "\n\n") and generates a new script that will print the code of each block before executing it, along with the timings of each block's execution.

Let's check the code of the simple `set-x-demo.nu` script

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

Let's see how `dotnu set-x` will modify this script

```nushell
dotnu set-x $filename --echo | lines | table -i false
# => ╭─────────────────────────────────────────────────────────────────────────────────╮
# => │ mut $prev_ts = ( date now )                                                     │
# => │ print ("> sleep 0.5sec" | nu-highlight)                                         │
# => │ sleep 0.5sec                                                                    │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
# => │                                                                                 │
# => │                                                                                 │
# => │ print ("> sleep 0.7sec" | nu-highlight)                                         │
# => │ sleep 0.7sec                                                                    │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
# => │                                                                                 │
# => │                                                                                 │
# => │ print ("> sleep 0.8sec" | nu-highlight)                                         │
# => │ sleep 0.8sec                                                                    │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
# => │                                                                                 │
# => │                                                                                 │
# => ╰─────────────────────────────────────────────────────────────────────────────────╯
```

### dotnu generate-numd

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
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

Pipe a `.nu` script into this command to convert it into `.numd` format (markdown with code blocks).

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

### dotnu extract-command-code

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

This command is useful for debugging. It extracts a command from a module, resolves its parameter defaults, and creates a standalone script you can source to get all variables in scope.

### dotnu list-exported-commands

```nushell
dotnu list-exported-commands --help
# => Usage:
# =>   > list-exported-commands {flags} <$path>
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>   --export: use only commands that are exported
# =>
# => Parameters:
# =>   $path <path>
# =>
# => Input/output types:
# =>   ╭───┬───────┬────────╮
# =>   │ # │ input │ output │
# =>   ├───┼───────┼────────┤
# =>   │ 0 │ any   │ any    │
# =>   ╰───┴───────┴────────╯
# =>
```

List commands defined in a module file. Use `--export` to show only exported commands.

### dotnu module-commands-code-to-record

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

Extracts all commands from a module file and returns them as a record where keys are command names and values are their source code.
