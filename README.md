# dotnu - generate scripts from `.nu` scripts ﻿🤯

## Quickstart

```nushell no-run
> git clone https://github.com/nushell-prophet/dotnu; cd dotnu
> use dotnu
```

## Commands

### dotnu set-x

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

### dotnu parse-docstrings

```nushell
> dotnu parse-docstrings --help | numd parse-help
Description:
  Parse commands definitions with their docstrings, output a table.

Usage:
  > parse-docstrings (file)

Flags:

Parameters:
  file <any> (optional)
```

### dotnu update-docstring-examples

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
  module_file <path>:
```

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
  ...paths <path>: paths to a .nu module files

Examples:
  > dependencies tests/assets/example-mod1.nu tests/assets/example-mod2.nu
  | first 3
  ╭─#─┬──caller───┬─────callee─────┬─filename_of_caller─┬─step─╮
  │ 0 │ command-3 │ lscustom       │ example-mod1.nu    │    0 │
  │ 1 │ command-3 │ sort-by-custom │ example-mod1.nu    │    0 │
  │ 2 │ command-5 │ command-3      │ example-mod1.nu    │    0 │
  ╰───┴───────────┴────────────────┴────────────────────┴──────╯
```

### dotnu filter-commands-with-no-tests

```nushell
> dotnu filter-commands-with-no-tests --help | numd parse-help
Description:
  Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.

Usage:
  > filter-commands-with-no-tests

Flags:
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
  $module_file <any>:
```
