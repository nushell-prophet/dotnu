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

Embed helpers automate three steps:

1. **Capture** – run the command and collect whatever it prints.
2. **Format** – turn that output into comment lines that start with `# => `.
3. **Insert / refresh** – put those lines below the command, or update them later.

All of this is pure Nushell—no external tools.

### The `dotnu embeds-update` command

`embeds-update` takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

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
# =>   ╭─#─┬─input─┬─output─╮
# =>   │ 0 │ any   │ any    │
# =>   ╰─#─┴─input─┴─output─╯
# =>
```

## Commands

### dotnu dependencies

```nushell
> dotnu dependencies --help
```

### dotnu filter-commands-with-no-tests

```nushell
> dotnu filter-commands-with-no-tests --help
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
