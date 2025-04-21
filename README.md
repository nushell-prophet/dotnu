![dotnu](https://github.com/user-attachments/assets/4fb74e46-f75b-4155-8e61-8ff75db66117)

<h1 align="center"><strong>dotnu - tools for Nushell module developers 🛠️</strong></h1>

<p align="center"><em>(A good companion for <a href="https://github.com/nushell-prophet/numd">numd</a>)</em></p>

## dotnu video demo

<a href="https://youtu.be/-C7_dfLXXrE">
  <img src="https://github.com/user-attachments/assets/fdd07bfc-7d77-4dca-8a1c-3e27ac3063f9" alt="dotnu demo" width="100"/>
</a>

## Quickstart

```nushell no-run
> git clone https://github.com/nushell-prophet/dotnu; cd dotnu
> use dotnu
```

## Commands

### dotnu dependencies

```nushell
> dotnu dependencies --help | numd parse-help
// Description:
//   Check .nu module files to determine which commands depend on other commands.
//
//
// Usage:
//   > dependencies {flags} ...(paths)
//
//
// Flags:
//   --keep-builtins: keep builtin commands in the result page
//   --definitions-only: output only commands' names definitions
//
//
// Parameters:
//   ...paths <path>: paths to nushell module files
//
//
// Input/output types:
//   ╭─#─┬─input─┬─output─╮
//   │ 0 │ any   │ any    │
//   ╰─#─┴─input─┴─output─╯
//
//
// Examples:
//   > dependencies ...( glob tests/assets/module-say/say/*.nu )
//   ╭─#─┬──caller──┬─filename_of_caller─┬──callee──┬─step─╮
//   │ 0 │ hello    │ hello.nu           │          │    0 │
//   │ 1 │ question │ ask.nu             │          │    0 │
//   │ 2 │ say      │ mod.nu             │ hello    │    0 │
//   │ 3 │ say      │ mod.nu             │ hi       │    0 │
//   │ 4 │ say      │ mod.nu             │ question │    0 │
//   │ 5 │ hi       │ mod.nu             │          │    0 │
//   │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
//   ╰───┴──────────┴────────────────────┴──────────┴──────╯
```

### dotnu filter-commands-with-no-tests

```nushell
> dotnu filter-commands-with-no-tests --help | numd parse-help
// Description:
//   Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.
//
//
// Usage:
//   > filter-commands-with-no-tests
//
//
// Input/output types:
//   ╭─#─┬─input─┬─output─╮
//   │ 0 │ any   │ any    │
//   ╰─#─┴─input─┴─output─╯
//
//
// Examples:
//   > dependencies ...( glob tests/assets/module-say/say/*.nu ) | filter-commands-with-no-tests
//   ╭─#─┬──caller──┬─filename_of_caller─╮
//   │ 0 │ hello    │ hello.nu           │
//   │ 1 │ question │ ask.nu             │
//   │ 2 │ say      │ mod.nu             │
//   ╰───┴──────────┴────────────────────╯
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
│ mut $prev_ts = ( date now )                                                     │
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
│                                                                                 │
╰─────────────────────────────────────────────────────────────────────────────────╯
```

### dotnu generate-nupm-tests

```nushell
> dotnu generate-nupm-tests --help | numd parse-help
// Description:
//   Generate nupm tests from examples in docstrings
//
//
// Usage:
//   > generate-nupm-tests {flags} <$module_path>
//
//
// Flags:
//   --echo: output script to stdout instead of updating the module_path provided
//
//
// Parameters:
//   $module_path <path>: path to a nushell module file
//
//
// Input/output types:
//   ╭─#─┬─input─┬─output─╮
//   │ 0 │ any   │ any    │
//   ╰─#─┴─input─┴─output─╯
```
