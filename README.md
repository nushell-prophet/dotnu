# dotnu - tools for nushell modules and scripts

## Quickstart

```nushell no-run
> git clone https://github.com/nushell-prophet/dotnu; cd dotnu
> use dotnu
```

## Commands

### dotnu dependencies

```nushell
> dotnu dependencies --help | numd parse-help
Description:
  Check .nu module files to determine which commands depend on other commands.

Usage:
  > dependencies {flags} ...(paths)

Flags:
  --keep_builtins - keep builtin commands in the result page
  --definitions_only - output only commands' names definitions

Parameters:
  ...paths <path>: paths to nushell module files

Examples:
  > dependencies ...(glob tests/assets/a/*.nu)
  ╭─#─┬──────caller──────┬──────callee──────┬─filename_of_caller─┬─step─╮
  │ 0 │ test-hello       │ hello            │ test-hello.nu      │    0 │
  │ 1 │ hello            │                  │ hello.nu           │    0 │
  │ 2 │ neutral-question │                  │ small-talk.nu      │    0 │
  │ 3 │ dialogue         │ hello            │ dialogue.nu        │    0 │
  │ 4 │ dialogue         │ hi               │ dialogue.nu        │    0 │
  │ 5 │ dialogue         │ neutral-question │ dialogue.nu        │    0 │
  │ 6 │ hi               │                  │ dialogue.nu        │    0 │
  ╰───┴──────────────────┴──────────────────┴────────────────────┴──────╯
```

### dotnu filter-commands-with-no-tests

```nushell
> dotnu filter-commands-with-no-tests --help | numd parse-help
Description:
  Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.

Usage:
  > filter-commands-with-no-tests

Examples:
  > dependencies ...(glob tests/assets/a/*.nu) | filter-commands-with-no-tests
  ╭─#─┬──────caller──────┬─filename_of_caller─╮
  │ 0 │ neutral-question │ small-talk.nu      │
  │ 1 │ dialogue         │ dialogue.nu        │
  │ 2 │ hi               │ dialogue.nu        │
  ╰───┴──────────────────┴────────────────────╯
```

### dotnu parse-docstrings

`dotnu parse-docstrings` parses command definitions along with their docstrings from a module file and outputs a table.

To check it in action let's first examine an example module:

```nushell
> let hello_module_path = [tests assets a hello.nu] | path join
> open $hello_module_path | lines
╭────┬──────────────────────────────────╮
│  0 │ # Output greeting!               │
│  1 │ #                                │
│  2 │ # Say hello to Maxim             │
│  3 │ # > hello Maxim                  │
│  4 │ # hello Maxim!                   │
│  5 │ #                                │
│  6 │ # Say hello to Darren            │
│  7 │ # and capitlize letters          │
│  8 │ # > hello Darren                 │
│  9 │ # | str capitalize               │
│ 10 │ # Hello Darren!                  │
│ 11 │ export def main [name: string] { │
│ 12 │     $"hello ($name)!"            │
│ 13 │ }                                │
╰────┴──────────────────────────────────╯
```

And now let's use `dotnu parse-docstrings` and see its structured output (I get 0 row here for better output formatting).

```nushell
> dotnu parse-docstrings $hello_module_path | reject input | get 0 | table -e
╭─────────────────────┬──────────────────────────────────────────────────────────────────╮
│ command_name        │ hello                                                            │
│ command_description │ Output greeting!                                                 │
│                     │ ╭─#─┬──────annotation───────┬─────command──────┬────result─────╮ │
│ examples            │ │ 0 │ Say hello to Maxim    │ > hello Maxim    │ hello Maxim!  │ │
│                     │ │ 1 │ Say hello to Darren   │ > hello Darren   │ Hello Darren! │ │
│                     │ │   │ and capitlize letters │ | str capitalize │               │ │
│                     │ ╰─#─┴──────annotation───────┴─────command──────┴────result─────╯ │
╰─────────────────────┴──────────────────────────────────────────────────────────────────╯
```

`dotnu parse-docstrings` uses the following assumptions:
1. The command description and example blocks are divided by a line with only the '#' symbol.
2. The command description is optional.
3. Examples of command usage may contain their own annotations (rows before the line starting with `>`). Example annotations are optional.
4. Examples of command usage consist of consecutive lines starting with `>` or `|` symbols.

### dotnu update-docstring-examples

`dotnu update-docstring-examples` executes and updates examples in the specified nushell module file.

It also checks the current repository for uncommitted changes (this check can be disabled using `--no_git_check`) to prevent data loss.

If an example produces an error, this error is printed to the terminal output, and the file is updated with the text `example update failed` on the failed example result place.

```nushell
> dotnu update-docstring-examples --help | numd parse-help
Description:
  Execute examples in the docstrings of the module commands and update the results accordingly.

Usage:
  > update-docstring-examples {flags} <module_file>

Flags:
  --command_filter <String> - filter commands by their name to update examples at (default: '')
  --use_statement <String> - use statement to execute examples with (like 'use module.nu'). Can be omitted to try to deduce automatically (default: '')
  --echo - output script to stdout instead of updating the module_file provided
  --no_git_check - don't check for the emptiness of the working tree

Parameters:
  module_file <path>: path to a nushell module file
```

### dotnu set-x

`dotnu set-x` opens a regular .nu script. It divides it into blocks using the specified regex (by default, it is "\n\n") and generates a new script that will print the code of each block before executing it, along with the timings of each block's execution.

Let's check the code of the simple `set-x-demo.nu` script

```nushell
> let $filename = [tests assets set-x-demo.nu] | path join
> open $filename | lines | table -i false
╭──────────────╮
│ sleep 0.5sec │
│              │
│ sleep 0.7sec │
│              │
│ sleep 0.8sec │
╰──────────────╯
```

Let's see how `dotnu set-x` will modify this script

```nushell
> dotnu set-x $filename --echo | lines | table -i false
╭─────────────────────────────────────────────────────────────────────────────────╮
│ mut $prev_ts = date now                                                         │
│ print ("> sleep 0.5sec" | nu-highlight)                                         │
│ sleep 0.5sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
│                                                                                 │
│ print ("> sleep 0.7sec" | nu-highlight)                                         │
│ sleep 0.7sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
│                                                                                 │
│ print ("> sleep 0.8sec" | nu-highlight)                                         │
│ sleep 0.8sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
╰─────────────────────────────────────────────────────────────────────────────────╯
```

### dotnu generate-nupm-tests

```nushell
> dotnu generate-nupm-tests --help | numd parse-help
Description:
  Generate nupm tests from examples in docstrings

Usage:
  > generate-nupm-tests {flags} <$module_file>

Flags:
  --echo - output script to stdout instead of updating the module_file provided

Parameters:
  $module_file <path>: path to a nushell module file
```
