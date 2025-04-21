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

## Embeds — keeping examples in sync

`dotnu` lets you write **literate Nushell**: ordinary Nushell scripts that include the real command output right after each pipeline ending in `| print $in`. See the [capture example](/dotnu-capture.nu) to grasp the idea quickly.

The `| print $in` suffix lets scripts run directly without loading the `dotnu` module.

The main command is `dotnu embeds-update`.

`dotnu embeds-update` takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

You can run it on a file path (e.g., `dotnu embeds-update dotnu-capture.nu`) or pipe a script into it (e.g., `"ls | print $in" | dotnu embeds-update`).

```nushell
> dotnu embeds-update --help
# => Inserts captured output back into the script at capture points
# =>
# => Usage:
# =>   > embeds-update {flags} (file)
# =>
# => Flags:
# =>   --echo: output updates to stdout
# =>   -h, --help: Display the help message for this command
# =>
# => Parameters:
# =>   file <path>:  (optional)
# =>
# => Input/output types:
# =>   ╭─#─┬──input──┬─output──╮
# =>   │ 0 │ string  │ nothing │
# =>   │ 1 │ string  │ string  │
# =>   │ 2 │ nothing │ string  │
# =>   │ 3 │ nothing │ nothing │
# =>   ╰─#─┴──input──┴─output──╯
# =>
```

## Commands

### dotnu dependencies

```nushell
> dotnu dependencies --help
# => Check .nu module files to determine which commands depend on other commands.
# =>
# => Usage:
# =>   > dependencies {flags} ...(paths)
# =>
# => Flags:
# =>   --keep-builtins: keep builtin commands in the result page
# =>   --definitions-only: output only commands' names definitions
# =>   -h, --help: Display the help message for this command
# =>
# => Parameters:
# =>   ...paths <path>: paths to nushell module files
# =>
# => Input/output types:
# =>   ╭─#─┬─input─┬─output─╮
# =>   │ 0 │ any   │ any    │
# =>   ╰─#─┴─input─┴─output─╯
# =>
# => Examples:
# =>
# =>   > dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
# =>   ╭─#──┬──caller───┬─filename_of_caller──┬──callee───┬─step──╮
# =>   │ 0  │ hello     │ hello.nu            │           │     0 │
# =>   │ 1  │ question  │ ask.nu              │           │     0 │
# =>   │ 2  │ say       │ mod.nu              │ hello     │     0 │
# =>   │ 3  │ say       │ mod.nu              │ hi        │     0 │
# =>   │ 4  │ say       │ mod.nu              │ question  │     0 │
# =>   │ 5  │ hi        │ mod.nu              │           │     0 │
# =>   │ 6  │ test-hi   │ test-hi.nu          │ hi        │     0 │
# =>   ╰─#──┴──caller───┴─filename_of_caller──┴──callee───┴─step──╯
# =>
```

### dotnu filter-commands-with-no-tests

```nushell
> dotnu filter-commands-with-no-tests --help
# => Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.
# =>
# => Usage:
# =>   > filter-commands-with-no-tests
# =>
# => Flags:
# =>   -h, --help: Display the help message for this command
# =>
# => Input/output types:
# =>   ╭─#─┬─input─┬─output─╮
# =>   │ 0 │ any   │ any    │
# =>   ╰─#─┴─input─┴─output─╯
# =>
# => Examples:
# =>
# =>   > dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
# =>   ╭─#─┬──caller──┬─filename_of_caller─╮
# =>   │ 0 │ hello    │ hello.nu           │
# =>   │ 1 │ question │ ask.nu             │
# =>   │ 2 │ say      │ mod.nu             │
# =>   ╰─#─┴──caller──┴─filename_of_caller─╯
# =>
```

### dotnu set-x

`dotnu set-x` opens a regular .nu script. It divides it into blocks using the specified regex (by default, it is "\n\n") and generates a new script that will print the code of each block before executing it, along with the timings of each block's execution.

Let's check the code of the simple `set-x-demo.nu` script

```nushell
> let $filename = [tests assets set-x-demo.nu] | path join
> open $filename | lines | table -i false
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
> dotnu set-x $filename --echo | lines | table -i false
# => ╭────────────────────────────────────────────────────────────╮
# => │ mut $prev_ts = ( date now )                                │
# => │ print ("> sleep 0.5sec" | nu-highlight)                    │
# => │ sleep 0.5sec                                               │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'... │
# => │                                                            │
# => │                                                            │
# => │ print ("> sleep 0.7sec" | nu-highlight)                    │
# => │ sleep 0.7sec                                               │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'... │
# => │                                                            │
# => │                                                            │
# => │ print ("> sleep 0.8sec" | nu-highlight)                    │
# => │ sleep 0.8sec                                               │
# => │ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'... │
# => │                                                            │
# => │                                                            │
# => ╰────────────────────────────────────────────────────────────╯
```
