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

<!-- numd-gen: use ../numd/numd; use dotnu; numd doc 'dotnu embeds-update' -->

The main command. It takes a script, rewrites every `print $in` line so its output is easy to parse, runs the modified script, captures what each marked line prints, and then replaces the old `# =>` blocks in the original file with the fresh output.

You can run it on a file path (e.g., `dotnu embeds-update dotnu-capture.nu`) or pipe a script into it (e.g., `"ls | print $in" | dotnu embeds-update`).

### Helper commands

While it is easy to write scripts in an editor, there are several convenience helper commands that facilitate populating script files from the terminal.

<!-- numd-gen: numd doc 'dotnu embed-add' --header-level 4 -->

Capture only the pipeline you run it on; useful for fine-grained examples. Pass `--capture-path` to point at a capture file; it is remembered for later calls in the same session.

<!-- numd-gen: numd doc 'dotnu embeds-remove' --header-level 4 -->

Strip all captured output, leaving clean code.

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

<!-- numd-gen: numd doc 'dotnu dependencies' -->

<!-- numd-gen: numd doc 'dotnu filter-commands-with-no-tests' -->

## Script Profiling

<!-- numd-gen: numd doc 'dotnu set-x' -->

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

<!-- numd-gen: numd doc 'dotnu generate-numd' -->

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

<!-- numd-gen: numd doc 'dotnu module-commands-code-to-record' -->

