# dotnu commands implementation
#
# All commands are exported by default for internal use, testing, and development.
# Public API is controlled by mod.nu which selectively re-exports user-facing commands.
# To make a command public, add it to the export list in mod.nu.

# Regex matching a capture point: a pipeline line ending in `| print $in`.
# Why: `find-capture-points` and `execute-and-parse-results` must agree on what a
# capture point is — they are zipped together in `embeds-update`, so any disagreement
# misaligns outputs against the wrong lines.
const capture_point = '\|\s*print\s+\$in\s*$'

# Check .nu module files to determine which commands depend on other commands.
@example 'Analyze command dependencies in a module' {
    dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
} --result [{caller: question filename_of_caller: "ask.nu" callee: null step: 0} {caller: hello filename_of_caller: "hello.nu" callee: null step: 0} {caller: say callee: hello filename_of_caller: "mod.nu" step: 0} {caller: say callee: hi filename_of_caller: "mod.nu" step: 0} {caller: say callee: question filename_of_caller: "mod.nu" step: 0} {caller: hi filename_of_caller: "mod.nu" callee: null step: 0} {caller: test-hi callee: hi filename_of_caller: "test-hi.nu" step: 0}]
export def 'dependencies' [
    ...paths: path # paths to nushell module files
    --keep-builtins # keep builtin commands in the result page
    --definitions-only # output only commands' names definitions
] {
    let callees_to_merge = $paths
        | sort # ensure consistent order across platforms
        | each {
            list-module-commands $in --keep-builtins=$keep_builtins --definitions-only=$definitions_only
        }
        | flatten

    if $definitions_only { return $callees_to_merge }

    # Expand chains only through unseen (caller, callee) pairs. A duplicate pair
    # would be dropped by the final `uniq-by` anyway, and expanding it again
    # loops forever on recursive commands (caller reachable from its own callee).
    generate {|state|
        if ($state.frontier | is-not-empty) {
            let next = $state.frontier
                | join-next $callees_to_merge
                | uniq-by caller callee
                | where {|row| [$row.caller $row.callee] not-in $state.seen }
            {
                out: $state.frontier
                next: {
                    frontier: $next
                    seen: ($state.seen ++ ($next | each {|row| [$row.caller $row.callee] }))
                }
            }
        }
    } {
        frontier: ($callees_to_merge | insert step 0)
        seen: ($callees_to_merge | each {|row| [$row.caller $row.callee] })
    }
    | flatten
    | uniq-by caller callee
}

# Filter commands after `dotnu dependencies` that aren't used by any test command.
# Test commands are detected by: name contains 'test' OR file matches 'test*.nu'
@example 'Find commands not covered by tests' {
    dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
} --result [[caller filename_of_caller]; [question "ask.nu"] [hello "hello.nu"] [say "mod.nu"]]
export def 'filter-commands-with-no-tests' [] {
    let input = $in
    let covered_with_tests = $input
        | where caller =~ 'test' or filename_of_caller =~ '^test.*\.nu$'
        | get callee
        | compact
        | uniq

    $input
    | reject callee step
    | uniq-by caller
    | where caller !~ 'test' and filename_of_caller !~ '^test.*\.nu$'
    | where caller not-in $covered_with_tests
}

# Open a regular .nu script. Divide it into blocks by "\n\n". Generate a new script
# that will print the code of each block before executing it, and print the timings of each block's execution.
@example 'Generate script with timing instrumentation' {
    set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text
} --result 'mut $prev_ts = ( date now )
print ("> sleep 0.5sec" | nu-highlight)
sleep 0.5sec
'
export def 'set-x' [
    file: path # path to `.nu` file
    --regex: string # regex to split on blocks (default: '\n+\n' - blank lines)
    --echo # output script to terminal
    --quiet # don't print any messages
] {
    let regex = $regex | default "\n+\n"
    let out_file = $file | str replace --regex '(\.nu)?$' '_setx.nu'

    open $file
    | normalize-newlines
    | str trim --char (char nl)
    | split row --regex $regex
    | each {|block|
        $block
        | escape-for-quotes
        | (
            'print ("> ' + $in + '" | nu-highlight)' + (char nl) + $block
            + "\nprint $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);\n\n"
        )
    }
    | prepend 'mut $prev_ts = ( date now )'
    | str join "\n"
    | $in + "\n"
    | if $echo { return $in } else {
        save --force $out_file

        if not $quiet {
            print $'the file ($out_file) is produced. Source it'
        }
        commandline edit --replace $'source ($out_file)'
    }
}

# Generate `.numd` from `.nu` divided into blocks by "\n\n"
export def 'generate-numd' [] {
    split row --regex "\n+\n"
    | each { $"```nu\n($in)\n```\n" }
    | to text
}

# Extract command code from a module and save it as a `.nu` file that can be sourced.
# By executing this `.nu` file, you'll have all the variables in your environment for debugging or development.
export def 'extract-command-code' [
    module_path: path # path to a Nushell module file
    command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save the extracted command script
    --clear-vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
    --set-vars: record = {} # set variables for a command
    --code-editor: string = 'code' # code is my editor of choice to open the result file
] {
    let command = $command
        | if $in =~ '\s' and $in !~ "^(\"|')" {
            $'"($in)"'
        } else { }

    let dotnu_vars_delim = '#dotnu-vars-end'

    let extracted_command = dummy-command $command $module_path $dotnu_vars_delim
        | nu -n -c $in
        | split row $dotnu_vars_delim

    if $extracted_command.1? == null {
        error make --unspanned {msg: $'no command `($command)` was found'}
    }

    let filename = $output
        | default $'($command | str trim --char '"' | str trim --char "'").nu'

    # here we use defined variables from the previously extracted command to a file
    let variables_from_prev_script = if ($filename | path exists) and not $clear_vars {
        open $filename
        | split row $dotnu_vars_delim
        | get 0
        | variable-definitions-to-record
    } else { {} }

    $extracted_command.0
    | variable-definitions-to-record
    | merge $variables_from_prev_script
    | merge $set_vars
    | items {|k v| $'let $($k) = ($v | to nuon)' }
    | prepend $'source ($module_path)'
    | append $dotnu_vars_delim
    | append $extracted_command.1
    | str join "\n"
    | $in + "\n"
    | if $echo {
        return $in
    } else {
        save --force $filename

        $" ^($code_editor) \"($filename)\"; commandline edit --replace ' source \"($filename)\"'"
        | commandline edit --replace $in
    }
}

# Extract a command with its dependency cascade from a module into one self-contained script.
#
# Runtime analog of `extract-command-code`: the module is imported into a clean `nu -n`
# process and command bodies are dumped via `view source`, so Nushell itself resolves
# `export use` chains, submodules and `main` renaming.
#
# Importing runs `export-env` blocks (the module's own and those of transitively imported
# local modules) — the only channel of arbitrary code execution at import — so the command
# refuses modules containing `export-env` unless --allow-export-env is set. Even then,
# `export-env` blocks are not carried into the output, so commands relying on `$env` values
# they set will extract fine but break at runtime.
#
# Known limits: imports of external modules (`std` etc.) are reproduced as `use` lines in
# the output, not embedded, and their own `export-env` blocks are outside the safety scan;
# attributes (`@example`) are dropped by `view source`; commands exposed with a submodule
# prefix (`use sub.nu` without `*` or an item list) land in the output as plain `def`
# because their prefixed names can't be matched back to the static scan.
export def extract-module-command [
    module_path: path # path to a module directory or a single .nu module file
    command_name: string # exposed name of the command to extract (`main` means the module itself)
    --allow-export-env # proceed even when the module contains export-env blocks
    --output: path # save the assembled script to this file instead of returning it
] {
    let module = module-files $module_path
    let scan = $module.files | each {|file| scan-module-file $file } | flatten

    let env_files = $scan | where kind == 'export-env' | get file | uniq
    if not $allow_export_env and ($env_files | is-not-empty) {
        error make --unspanned {
            msg: (
                "importing this module would run `export-env` blocks from:\n"
                + ($env_files | str join (char nl))
                + "\nInspect them, then rerun with `--allow-export-env` to accept that."
            )
        }
    }

    let local_uses = $scan | where kind == 'use' and resolved_use != null
    if not $module.is_dir and ($local_uses | is-not-empty) {
        error make --unspanned {
            msg: (
                "a single-file module with local imports can't be extracted — the imported files are outside the module:\n"
                + ($local_uses.statement | str join (char nl))
            )
        }
    }

    let escaping = $local_uses | where {|row|
            try {
                $row.resolved_use | path relative-to $module.source | ignore
                false
            } catch { true }
        }
    if ($escaping | is-not-empty) {
        error make --unspanned {
            msg: (
                "these imports resolve outside the module directory and would break in the extraction copy:\n"
                + ($escaping.statement | str join (char nl))
            )
        }
    }

    let defs = $scan | where kind == 'def'
    let duplicated = $defs
        | group-by name --to-table
        | where {|group| ($group.items.file | uniq | length) > 1 }
    if ($duplicated | is-not-empty) {
        # after export-ification same-named commands from different files would
        # silently shadow each other (last import wins), extracting the wrong body
        error make --unspanned {
            msg: (
                "the same command name is defined in several module files:\n"
                + ($duplicated | each { $"($in.name): ($in.items.file | uniq | str join ', ')" } | str join (char nl))
            )
        }
    }

    # temp copy named after the module, so its `main` is exposed under the module name
    let tmp_dir = mktemp --directory
    let copy = $tmp_dir | path join (if $module.is_dir { $module.name } else { $module.name + '.nu' })
    if $module.is_dir {
        cp --recursive $module.source $copy
    } else {
        cp $module.source $copy
    }

    # make everything reachable from outside: private defs and private local imports
    # become `export def` / `export use` — in the copy only
    $module.files | each {|file|
        let offsets = $scan
            | where {|row|
                $row.file == $file and not $row.exported and (
                    $row.kind == 'def' or ($row.kind == 'use' and $row.resolved_use != null)
                )
            }
            | get start
        let copy_file = if $module.is_dir {
            $copy | path join ($file | path relative-to $module.source)
        } else { $copy }
        export-ify-file $copy_file $offsets
    }

    let sources = dump-module-commands $copy $module.name
    rm --recursive --force $tmp_dir

    let names = $sources | get name
    let target = $command_name | if $in == 'main' { $module.name } else { }
    if $target not-in $names {
        error make --unspanned {
            msg: $"no command `($target)` among the module commands: ($names | str join ', ')"
        }
    }

    let edges = $sources
        | insert calls {|row|
            $row.source
            | ast-complete
            | where shape in ['shape_internalcall' 'shape_external']
            | get content
            | uniq
            | where $it in $names and $it != $row.name
        }
        | select name calls

    # cascade: BFS from the target over the call graph
    mut reachable = [$target]
    mut frontier = [$target]
    while ($frontier | is-not-empty) {
        let front = $frontier
        let known = $reachable
        let next = $edges
            | where name in $front
            | get calls
            | flatten
            | uniq
            | where $it not-in $known
        $reachable = $reachable ++ $next
        $frontier = $next
    }

    # dependencies before dependents: the parser requires a def before its call site
    mut ordered = []
    mut remaining = $reachable
    while ($remaining | is-not-empty) {
        let rem = $remaining
        let ready = $edges
            | where name in $rem
            | where {|row| $row.calls | where $it in $rem | is-empty }
            | get name
        if ($ready | is-empty) {
            # unreachable: a call cycle between top-level defs can't parse in Nushell
            error make --unspanned {msg: 'internal error: call-graph cycle in topological sort'}
        }
        $ordered = $ordered ++ $ready
        $remaining = $rem | where $it not-in $ready
    }

    # `view source` returns every body as plain `def` — restore `export` where the origin had it
    # Not bare `where exported` because: topiary's nushell grammar can't parse it
    let exported_names = $defs | where exported == true | get name
    let header = $scan
        | where kind == 'use' and resolved_use == null
        | get statement
        | str replace --regex '^export ' ''
        | uniq

    let script = $ordered
        | each {|name|
            $sources
            | where name == $name
            | get 0.source
            | if $name in $exported_names { 'export ' + $in } else { }
        }
        | prepend $header
        | str join ((char nl) + (char nl))
        | $in + (char nl)

    # fail fast on any exposure case the assembly can't map (see "Known limits" above)
    let check = nu -n -c $script | complete
    if $check.exit_code != 0 {
        error make --unspanned {
            msg: $"assembled script does not parse under `nu -n`:\n($check.stderr)"
        }
    }

    if $output == null { $script } else { $script | save --force $output }
}

# List all exported definitions from a module file
#
# Finds commands from `export def` and `export use` patterns, including bare
# and glob re-exports (resolved by reading the referenced submodule).
export def 'list-module-exports' [
    path: path
]: nothing -> list<string> {
    open $path --raw
    | extract-exported-commands ($path | path expand | path dirname)
    | replace-main-with-module-name $path
    | if ($in | is-empty) {
        print 'No command found'
        return
    } else { }
}

# List module's callable interface (main commands)
#
# Finds `def main` and `def 'main subcommand'` patterns - the commands
# available when you `use` the module.
export def 'list-module-interface' [
    path: path
]: nothing -> list<string> {
    open $path --raw
    | lines
    | where $it =~ '^(export )?def '
    | extract-command-name
    | where $it starts-with 'main'
    | str replace 'main ' ''
    | if ($in | is-empty) {
        print 'No command found'
        return
    } else { }
}

# todo: make configuration like --autocommit in file itself

# Inserts captured output back into the script at capture points
export def 'embeds-update' [
    file?: path
    --echo # output updates to stdout
]: [string -> nothing string -> string nothing -> string nothing -> nothing] {
    let input = $in

    if $input == null and $file == null {
        error make {msg: 'pipe in a script or provide a path'}
    }

    let script = if $input == null { open $file } else { $input }
        | normalize-newlines
        | embeds-remove

    let results = execute-and-parse-results $script --script_path=$file

    let replacements = $script
        | find-capture-points
        | zip $results

    let prevent_second_replacement = " # to-not-be-replaced-again"

    $replacements
    # Why: prepend a newline so a capture point on the very first line is anchored
    # by "\n" on both sides like any interior line; without it the match silently no-ops
    | reduce --fold ("\n" + $script) {|it|
        str replace ("\n" + $it.0 + "\n") ("\n" + $it.0 + $prevent_second_replacement + "\n" + $it.1 + "\n")
    }
    | str replace --regex '^\n' '' # strip the single leading newline added above
    | str replace --all $prevent_second_replacement ''
    | str replace --all --regex '\n{3,}' "\n\n"
    | str replace --regex "\n*$" "\n"
    | if $echo or ($input != null) { } else { save --force $file }
}

# Execute @example blocks and update their --result values
# Similar to embeds-update but for @example attributes
export def 'examples-update' [
    file: path # path to .nu file with @example blocks
    --echo # output updates to stdout instead of saving
] {
    let content = open $file
        | normalize-newlines

    let examples = $content | find-examples

    if ($examples | is-empty) {
        if $echo { return $content }
        return
    }

    # Execute each example and collect results
    let results = $examples | each {|ex|
            let result = execute-example $ex.code $file
            if ($result | describe) == "record<error: string>" {
                # Skip failed examples - don't corrupt the file with error messages
                print --stderr $"Warning: Example execution failed in ($file | path basename):"
                print --stderr $"  Code: ($ex.code)"
                print --stderr $"  Error: ($result.error | lines | first)"
                null
            } else {
                {
                    original: $ex.original
                    new_result: $result
                }
            }
        }
        | compact

    # Replace each example's original block with updated version
    # Using full original text ensures unique matches even with duplicate results
    let updated = $results | reduce --fold $content {|item acc|
            # Build new example by replacing just the result value in the original
            # Escape $ as $$ to prevent regex backreference interpretation
            let escaped_result = $item.new_result | str replace --all '$' '$$'
            let new_example = $item.original
                | str replace --regex '\} --result .+$' $"} --result ($escaped_result)"

            $acc | str replace $item.original $new_example
        }

    $updated
    | if $echo { } else { save --force $file }
}

# Generate code lines from `#**` directive comments — the inverse of `embeds-update`.
#
# `embeds-update` runs code and writes its *output* back as `# =>` comments. `expand-code`
# runs a pipeline written *inside* a `#** <pipeline>` comment and writes that pipeline's text
# result back as real code lines, right after the directive and up to the matching `#**end`.
#
# The directive and end marker are never touched, so re-running only refreshes the lines
# between them — keeping generated code in sync with whatever the pipeline reads.
export def 'expand-code' [
    file?: path # .nu file to expand in place; omit to pipe the script in and get the result back
    --echo # output the result to stdout instead of saving to the file
]: [string -> string nothing -> string nothing -> nothing] {
    let input = $in

    if $input == null and $file == null {
        error make {msg: 'pipe in a script or provide a path'}
    }

    let source_lines = (if $input == null { open $file } else { $input })
        | normalize-newlines
        | lines

    let dir = if $file != null { $file | path dirname } else { $env.PWD }

    let expanded = $source_lines
        | find-expand-directives
        | insert output {|d| run-expand-pipeline $d.pipeline $dir }

    # Single pass: emit the directive then its fresh output, skip the old generated lines
    # (strictly between directive and `#**end`), and emit every other line — including the
    # `#**end` marker — unchanged. `skip_to` marks the last stale line to drop.
    let result = $source_lines
        | enumerate
        | reduce --fold {out: [] skip_to: (-1)} {|it acc|
            let idx = $it.index # Why: `where` below rebinds `$it` to its own row, shadowing this one
            let directive = $expanded | where start == $idx
            if not ($directive | is-empty) {
                {
                    out: ($acc.out | append $it.item | append $directive.0.output)
                    skip_to: ($directive.0.end - 1)
                }
            } else if $it.index <= $acc.skip_to {
                $acc
            } else {
                {out: ($acc.out | append $it.item) skip_to: $acc.skip_to}
            }
        }
        | get out
        | str join "\n"
        | $in + "\n"

    if $echo or ($input != null) { $result } else { $result | save --force $file }
}

# Scan script lines for `#** <pipeline>` … `#**end` blocks.
#
# Returns one row per directive with its 0-based `start` line, matching `end` line, and the
# `pipeline` text after the marker. Errors on an unclosed directive, an empty pipeline, or a
# stray `#**end`.
#
# Why: `expand-code` gets its own scanner rather than sharing one with `embeds`/`numd`. The
# marker shapes differ enough (`# =>` vs fenced blocks vs `#**`…`#**end`) that a shared helper
# would be mostly branching. Factor one out later only if the scanning code clearly repeats.
export def find-expand-directives []: list<string> -> table<start: int, end: int, pipeline: string> {
    let paired = $in
        | enumerate
        | where item =~ '^\s*#\*\*'
        | reduce --fold {open: null pairs: []} {|it acc|
            if $it.item =~ '^\s*#\*\*end\s*$' {
                if $acc.open == null {
                    error make {msg: $"`#**end` on line ($it.index + 1) has no matching `#**` directive"}
                }
                {
                    open: null
                    pairs: ($acc.pairs | append {start: $acc.open.index end: $it.index pipeline: $acc.open.pipeline})
                }
            } else {
                if $acc.open != null {
                    error make {msg: $"`#**` directive on line ($acc.open.index + 1) is not closed by `#**end` before the next directive on line ($it.index + 1)"}
                }

                let pipeline = $it.item | str replace --regex '^\s*#\*\*' '' | str trim
                if ($pipeline | is-empty) {
                    error make {msg: $"`#**` directive on line ($it.index + 1) has no pipeline"}
                }

                {open: {index: $it.index pipeline: $pipeline} pairs: $acc.pairs}
            }
        }

    if $paired.open != null {
        error make {msg: $"`#**` directive on line ($paired.open.index + 1) has no `#**end`"}
    }

    $paired.pairs
}

# Run a `#**` directive's pipeline in `dir` and return its text output split into code lines.
#
# Why: `--no-config-file` mirrors `embeds` — a directive pipeline is meant to be self-contained
# builtins, so config/env must not leak in and change its result.
export def run-expand-pipeline [
    pipeline: string
    dir: path
]: nothing -> list<string> {
    cd $dir

    # Why: `| print --no-newline` captures the pipeline's returned text exactly. The default
    # implicit print appends its own newline on top of `to text`'s, leaving a spurious trailing
    # blank line; with it suppressed, plain `lines` drops only the text's own terminator, so one
    # output line stays one code line and genuine leading/trailing blank lines survive.
    ^$nu.current-exe --no-config-file --commands ($pipeline + ' | print --no-newline')
    | complete
    | if $in.exit_code != 0 {
        error make {msg: $"`#**` pipeline failed: ($pipeline)\n($in.stderr)"}
    } else {
        $in.stdout
    }
    | lines
}

# Find @example blocks with their code and result sections using AST parsing
#
# Uses ast-complete to accurately detect @example attributes, avoiding false positives
# from @example inside strings or comments. The @ prefix appears as shape_gap.
export def find-examples []: string -> table<original: string, code: string, result_line: string> {
    let source = $in
    let bytes = $source | encode utf8
    let tokens = $source | ast-complete

    if ($tokens | is-empty) {
        return []
    }

    # Find @example: shape_gap ending with "@" followed by "example" token
    # The gap may include preceding newlines (e.g., "\n\n@")
    let example_indices = $tokens
        | enumerate
        | window 2
        | where {|pair|
            (
                $pair.0.item.shape == "shape_gap" and ($pair.0.item.content | str ends-with "@")
                and $pair.1.item.content == "example"
            )
        }
        | each { $in.1.index } # Get index of "example" token

    if ($example_indices | is-empty) {
        return []
    }

    # For each @example, extract components
    $example_indices | each {|idx|
        let remaining = $tokens | skip $idx

        # Find block tokens (shape_block) - opening and closing braces
        let block_tokens = $remaining
            | enumerate
            | where {|r| $r.item.shape == "shape_block" }

        if ($block_tokens | length) < 2 {
            # Malformed @example - skip
            return null
        }

        let open_brace = $block_tokens | first | get item
        let close_brace = $block_tokens | get 1 | get item

        # Check for --result flag after the closing brace
        let close_brace_idx = $block_tokens | get 1 | get index
        let after_block = $remaining | skip ($close_brace_idx + 1)

        # Skip whitespace/newlines to find the flag
        let after_block_meaningful = $after_block
            | where shape not-in ["shape_whitespace" "shape_newline"]

        let result_info = if ($after_block_meaningful | is-not-empty) and ($after_block_meaningful | first | get shape) == "shape_flag" and ($after_block_meaningful | first | get content) == "--result" {
            # Has --result flag - get the value token(s) (skip whitespace after flag)
            let result_tokens = $after_block_meaningful | skip 1
                | where shape not-in ["shape_whitespace" "shape_newline"]
            let first_token = $result_tokens | first

            # For lists/records, find matching closing bracket
            let end_byte = if $first_token.content == "[" or $first_token.content == "{" {
                let close_char = if $first_token.content == "[" { "]" } else { "}" }
                let open_char = $first_token.content
                # Find matching close by tracking bracket depth
                let close_token = $result_tokens | skip 1
                    | reduce --fold {depth: 1 token: null} {|t acc|
                        if $acc.token != null { $acc } else {
                            let new_depth = if $t.content == $open_char {
                                $acc.depth + 1
                            } else if $t.content == $close_char {
                                $acc.depth - 1
                            } else {
                                $acc.depth
                            }
                            if $new_depth == 0 { {depth: 0 token: $t} } else { {depth: $new_depth token: null} }
                        }
                    }
                $close_token.token.end
            } else {
                $first_token.end
            }

            {
                has_result: true
                end_byte: $end_byte
                result_line: "" # not used, kept for interface compatibility
            }
        } else {
            # No --result flag
            {
                has_result: false
                end_byte: $close_brace.end
                result_line: ""
            }
        }

        # Skip examples without --result (nothing to update)
        if not $result_info.has_result {
            return null
        }

        # Extract original text from @ to end of result value
        # The @ may be at end of a gap that includes newlines (e.g., "\n\n@")
        let at_token = $tokens | get ($idx - 1) # The gap token containing @
        let at_start = $at_token.end - 1 # @ is always the last char in the gap
        let original = $bytes | bytes at $at_start..<($result_info.end_byte) | decode utf8

        # Extract code from inside the block (between { and })
        let code_start = $open_brace.end
        let code_end = $close_brace.start
        let code = $bytes | bytes at $code_start..<$code_end | decode utf8 | str trim

        {
            original: $original
            code: $code
            result_line: $result_info.result_line
        }
    }
    | compact
    | where {|row| $row.code != '' }
}

# Execute example code and return the result as nuon
# Returns null on execution failure
export def execute-example [code: string file: path]: nothing -> any {
    let abs_file = $file | path expand
    let dir = $abs_file | path dirname
    let parent_dir = $dir | path dirname
    let module_name = $dir | path basename

    # Strip module prefix from code if present (e.g., "dotnu dependencies" -> "dependencies")
    let normalized_code = $code | str replace --regex $'^($module_name) ' ''

    # Build script: cd to parent, source file directly to access all functions
    let script = $"
        cd '($parent_dir)'
        source '($abs_file)'
        ($normalized_code) | to nuon
    "

    let result = do --ignore-errors { ^$nu.current-exe -n -c $script } | complete
    if $result.exit_code != 0 {
        # Return error info for caller to handle
        {error: ($result.stderr | str trim | default "unknown error")}
    } else {
        $result.stdout | str trim
    }
}

# Set environment variables to operate with embeds
export def --env 'embeds-setup' [
    path?: path
    --auto-commit
] {
    $env.dotnu.embeds-capture-path = (
        $path
        | if $in == null {
            get-dotnu-capture-path
        } else {
            str replace --regex '(\.nu)?$' '.nu' # make sure that the script has .nu extension
        }
        | path expand
    )

    if $auto_commit {
        touch $env.dotnu.embeds-capture-path

        git-autocommit-dotnu-capture

        $env.dotnu.auto-commit = true
    }
}

# Embed stdin together with its command into the file
export def 'embed-add' [
    --pipe-further (-p) # output input further to the pipeline
    --published # output the published representation into terminal
    --dry_run
    #todo: --
] {
    let input = $in

    let path = get-dotnu-capture-path

    let command = if $input == null {
        get-command-from-hist | get previous
    } else {
        get-command-from-hist | get current
        | str replace --regex '(?s)\| ?dotnu embed-add.*$' ''
    }

    let commented_input = $input
        | if $in == null { } else {
            table --expand --width 160
            | comment-hash-colon
            | $"\n($in)\n"
        }

    let script_with_output = $"\n($command) | print $in\n($commented_input)"

    if $env.dotnu?.auto-commit? == true {
        git-autocommit-dotnu-capture
    }

    if not $dry_run { $script_with_output | save --append $path }

    if $published { return $script_with_output }
    if $pipe_further or $dry_run { return $input }
}

#### helpers
# they used to be separate from the main code, but I want to experiment with structure
# so all the commands are in one file now, and all are exported, to be available in my scripts
# that can use this file commands with 'use ..', though main commands are exported in mod.nu

export def 'get-dotnu-capture-path' [] {
    $env.dotnu?.embeds-capture-path? | default dotnu-embeds-capture.nu
}

# Normalize Windows CRLF line endings to LF; pass through unchanged elsewhere.
export def normalize-newlines []: string -> string {
    if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
}

export def 'git-autocommit-dotnu-capture' [] {
    let path = get-dotnu-capture-path

    git add $path
    git commit --only $path -m 'dotnu capture autocommit'
}

export def 'get-command-from-hist' [] {
    if $env.config.history.file_format == 'sqlite' {
        open $nu.history-path
        | query db "select command_line from history order by id desc limit 2"
        | get command_line
        | {previous: $in.1 current: $in.0}
    } else {
        # history | last $index | get command | first # returns the previous command
        print 'txt history file format is not supported'
    }
}

export def check-clean-working-tree [
    module_path: path
] {
    cd ($module_path | path dirname)

    let git_status = git status --short

    $git_status
    | lines
    | parse '{s} {m} {f}'
    | where f =~ $'($module_path | path basename)$'
    | is-not-empty
    | if $in {
        error make --unspanned {
            msg: (
                "Working tree isn't empty. Please commit or stash changed files, " +
                "or use `--no-git-check` flag. Uncommitted files:\n" + $git_status
            )
        }
    }
}

# Make a record from code with variable definitions
@example '' {
    "let $quiet = false; let no_timestamp = false" | variable-definitions-to-record
} --result {quiet: false no_timestamp: false}
@example '' {
    "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record
} --result {a: b c: d}
@example '' {
    "let $a = null" | variable-definitions-to-record
} --result {a: null}
export def variable-definitions-to-record []: string -> record {
    let script_with_variable_definitions = str replace --all ';' ";\n"
        | normalize-newlines
        | $in + (char nl)

    let parsed_vars = $script_with_variable_definitions
        | parse --regex 'let \$?(?<var>.*) ='

    if ($parsed_vars | is-empty) {
        return {}
    }

    let record_builder_code = $parsed_vars
        | get var
        | uniq
        | each { $'($in): $($in)' }
        | str join ' '
        | '{' + $in + '} | to nuon' # this way we ensure the proper formatting for bool, numeric and string vars

    let script = $script_with_variable_definitions + $record_builder_code

    let result = (nu -n -c $script | complete)
    if $result.exit_code != 0 {
        return {}
    }
    $result.stdout | from nuon | default {}
}

@example '' {
    'export def --env "test" --wrapped' | lines | last | extract-command-name
} --result "test"
export def 'extract-command-name' [
    module_path?: path # path to a nushell module file
] {
    str replace --regex '\[.*' ''
    | str replace --regex '^(export )?def ' ''
    | str replace --all --regex '(--(env|wrapped) ?)' ''
    | str replace --all --regex "\"|'|`" ''
    | str trim
}

export def replace-main-with-module-name [
    path: path
] {
    let input = $in
    let module_name = $path
        | path expand
        | path split
        | where $it != mod.nu
        | last
        | str replace --regex '\.nu$' ' '

    $input
    | str replace --regex '^main( |$)' $module_name
    | str trim
}

# Escapes symbols to be printed unchanged inside a `print "something"` statement.
@example '' {
    'abcd"dfdaf" "' | escape-for-quotes
} --result "abcd\\\"dfdaf\\\" \\\""
export def escape-for-quotes []: string -> string {
    str replace --all --regex '(\\|\")' '\$1'
}

# context aware completions for defined command names in nushell module files
@example '' {
    nu-completion-command-name 'dotnu extract-command-code tests/assets/b/example-mod1.nu' | first 3
} --result [main lscustom "command-5"]
export def nu-completion-command-name [
    context: string
] {
    $context | str replace --regex '^.*? extract-command-code ' ''
    | str trim | split row ' ' | first
    | path expand | open $in --raw | lines
    | where $it =~ '^(export )?def '
    | each { extract-command-name }
}

# Extract table with information on which commands use which commands
@example '' {
    list-module-commands tests/assets/b/example-mod1.nu | first 3
} --result [[caller callee filename_of_caller]; ["command-5" "command-3" "example-mod1.nu"] ["command-5" first-custom "example-mod1.nu"] ["command-5" append-random "example-mod1.nu"]]
@example '' {
    list-module-commands --definitions-only tests/assets/b/example-mod1.nu | first 3
} --result [[caller filename_of_caller]; ["example-mod1" "example-mod1.nu"] [lscustom "example-mod1.nu"] ["command-5" "example-mod1.nu"]]
export def list-module-commands [
    module_path: path # path to a .nu module file.
    --keep-builtins # keep builtin commands in the result page
    --definitions-only # output only commands' names definitions
] {
    let script_content = open $module_path --raw
        | normalize-newlines
    let all_tokens = $script_content | ast-complete
    let statements = $script_content | split-statements

    # Phase 1a: Find def statements using split-statements
    # Each statement has accurate byte ranges for scope detection
    let def_definitions = $statements
        | where { $in.statement =~ '^(export )?def ' }
        | insert caller { $in.statement | lines | first | extract-command-name | replace-main-with-module-name $module_path }
        | select caller start end

    # Phase 1b: Find attributes using ast-complete
    # The @ prefix appears as shape_gap, followed by the attribute token
    let attribute_definitions = $all_tokens
        | enumerate
        | window 2
        | where {|pair|
            $pair.0.item.shape == "shape_gap" and ($pair.0.item.content | str ends-with "@")
        }
        | each {|pair|
            let attr_token = $pair.1.item
            let at_start = $pair.0.item.end - 1 # @ is last char in the gap
            {caller: ('@' + ($attr_token.content | split row ' ' | first)) start: $at_start}
        }
        | insert end null # attributes don't have scope ranges

    let defined_defs = $def_definitions
        | append $attribute_definitions
        | insert filename_of_caller ($module_path | path basename)

    if $definitions_only or ($defined_defs | is-empty) {
        return ($defined_defs | select caller filename_of_caller)
    }

    let defs_by_start = $defined_defs | sort-by start

    # Why: compute the exclusion list once. A subexpression inside `where` is
    # re-evaluated per row, so an inline `help commands` here would run once per
    # token — expensive on the hot path (`dependencies` calls this per file).
    let excluded_types = if $keep_builtins { ['keyword'] } else { ['keyword' 'built-in'] }
    let excluded_commands = help commands | where command_type in $excluded_types | get name

    # Range-based lookup using statement boundaries
    # For defs with end ranges, tokens must be within [start, end)
    # For attributes (end=null), use the old "start <=" logic
    let calls = $all_tokens
        | each {|token|
            # Find the definition this token belongs to
            let matching_def = $defs_by_start
                | where {|d|
                    if $d.end? != null {
                        # Def with scope: token must be within range
                        $d.start <= $token.start and $token.start < $d.end
                    } else {
                        # Attribute: use start-based matching (find last one before token)
                        $d.start <= $token.start
                    }
                }
                | last

            if $matching_def == null {
                $token | insert caller null | insert filename_of_caller null
            } else {
                $token | insert caller $matching_def.caller | insert filename_of_caller $matching_def.filename_of_caller
            }
        }
        | where caller != null and caller !~ '^@' # exclude tokens inside attribute blocks
        | where shape in ['shape_internalcall' 'shape_external']
        | where content not-in $excluded_commands # exclude keywords (def, export def, etc.) and, unless --keep-builtins, built-ins
        | select caller content filename_of_caller
        | rename --column {content: callee}

    let defs_without_calls = $defined_defs
        | where caller !~ '^@' # exclude attribute decorators from output
        | select caller filename_of_caller
        | where caller not-in ($calls.caller | uniq)
        | insert callee null

    $calls | append $defs_without_calls
}

# Extract all commands from a module as a record of {command_name: source_code}
export def 'module-commands-code-to-record' [
    module_path: path # path to a Nushell module file
] {
    open $module_path --raw
    | normalize-newlines
    | split-statements
    | where statement =~ '^(export )?def '
    | each {|s|
        let name = $s.statement | lines | first
            | extract-command-name
            | replace-main-with-module-name $module_path
        {$name: $s.statement}
    }
    | into record
}

# Resolve a module path (a directory or a single .nu file) to its name, root and file list
export def module-files [
    module_path: path
]: nothing -> record<name: string, source: path, is_dir: bool, files: list<path>> {
    let expanded = $module_path | path expand
    if ($expanded | path type) == 'dir' {
        {
            name: ($expanded | path basename)
            source: $expanded
            is_dir: true
            files: (glob ($expanded | path join '**' '*.nu') | sort)
        }
    } else {
        {
            name: ($expanded | path parse | get stem)
            source: $expanded
            is_dir: false
            files: [$expanded]
        }
    }
}

# Classify a module file's top-level statements for `extract-module-command`.
#
# One row per statement: byte offset, kind (def / use / export-env / other), whether it's
# already exported, the def's exposed name (`main` renamed to the module name), and for
# `use` rows the absolute target path when it resolves to a local file or directory
# (null for external modules like `std`).
export def scan-module-file [
    file: path
]: nothing -> table {
    let dir = $file | path dirname

    open $file --raw
    | normalize-newlines
    | split-statements
    | insert file $file
    | insert kind {|row|
        if $row.statement =~ '^(export )?def ' {
            'def'
        } else if $row.statement =~ '^(export )?use ' {
            'use'
        } else if $row.statement =~ '^export-env\b' {
            'export-env'
        } else { 'other' }
    }
    | insert exported {|row| $row.statement | str starts-with 'export ' }
    | insert name {|row|
        if $row.kind == 'def' {
            $row.statement | lines | first | extract-command-name | replace-main-with-module-name $file
        } else { null }
    }
    | insert resolved_use {|row|
        if $row.kind != 'use' { null } else {
            let target = $row.statement
                | parse --regex r#'^(?:export )?use\s+(?:"(?<dq>[^"]+)"|'(?<sq>[^']+)'|(?<bare>\S+))'#
                | get 0
                | [$in.dq $in.sq $in.bare]
                | compact
                | first
            let candidate = if ($target | str starts-with '/') or ($target =~ '^[A-Za-z]:') {
                $target
            } else {
                $dir | path join $target
            }

            if ($candidate | path exists) { $candidate | path expand } else { null }
        }
    }
}

# Prefix the statements at the given byte offsets with `export ` — used on the temp copy
# to make private defs and private local imports reachable for `view source`
export def export-ify-file [
    file: path # rewritten in place
    offsets: list<int> # byte offsets of top-level statements, from `scan-module-file`
] {
    let source_bytes = open $file --raw | normalize-newlines | encode utf8

    $offsets
    | sort --reverse
    | reduce --fold $source_bytes {|off acc|
        ($acc | bytes at 0..<$off) ++ ('export ' | encode utf8) ++ ($acc | bytes at $off..)
    }
    | decode utf8
    | save --force $file
}

# Import an export-ified module copy in a clean `nu -n` and dump `name -> source` for
# every exposed command — one process for the whole module instead of one per command
export def dump-module-commands [
    copy_path: path # the export-ified temp copy (directory or single .nu file)
    module_name: string
]: nothing -> table<name: string, source: string> {
    let script = [
        $"use '($copy_path)' *"
        $"scope modules | where name == '($module_name)' | get 0.commands.name"
        "| each {|n| {name: $n source: (view source $n)} }"
        "| to nuon"
    ] | str join (char nl)

    let result = nu -n -c $script | complete
    if $result.exit_code != 0 {
        error make --unspanned {msg: $"module import failed:\n($result.stderr)"}
    }

    $result.stdout | from nuon
}

# Format example blocks (annotation, command, result) and a command description as `# `-prefixed comment lines
export def format-substitutions [
    examples: table
    command_description: string
] {
    $examples
    | each {|i|
        [$i.annotation $i.command $i.result]
        | compact --empty
        | str join (char nl) # `to text` produces trailing empty line
    }
    | prepend $command_description
    | compact --empty
    | str join $"(char nl)(char nl)"
    | lines
    | each { $"# ($in)" | str trim }
    | to text
}

# helper function for use inside of generate
@example '' {
    [[caller callee step filename_of_caller]; [a b 0 test] [b c 0 test]] | join-next $in
} --result [[caller callee step filename_of_caller]; [a c 1 test]]
export def 'join-next' [
    callees_to_merge: table
] {
    join --left $callees_to_merge callee caller
    | select caller callee_ step filename_of_caller
    | rename caller callee
    | upsert step {|i| $i.step + 1 }
    | where callee != null
}

export def 'dummy-command' [
    command: string
    file: path
    dotnu_vars_delim: string
] {
    # the closure below is used as highlighted in an editor constructor
    # for the command that will be executed in `nu -c`
    let dummy_closure = {|function|
        let params = scope commands
            | where name == $command
            | get --optional signatures.0
            | if $in == null {
                error make --unspanned {msg: 'no command $command was found'}
            } else { }
            | values
            | get 0
            | each {
                if ($in.parameter_type == 'rest') {
                    if ($in.parameter_name == '') {
                        # if rest parameters named $rest, in the signatures it doesn't have a name
                        upsert parameter_name 'rest'
                    } else { }
                    | default [] parameter_default
                } else { }
            }
            | where parameter_name != null
            | each {|i|
                let param = $i.parameter_name | str replace --all '-' '_' | str replace '$' ''

                let value = $i.parameter_default?
                    | default (if $i.parameter_type == 'switch' { false })
                    | to nuon # to handle nuls

                $"let $($param) = ($value) # ($i.syntax_shape)"
            }
            | to text

        let main = view source $command
            | lines
            | upsert 0 {|i| '# ' + $i }
            | drop
            | append '# }'
            | prepend $dotnu_vars_delim
            | to text

        "source '$file'\n\n" + $params + "\n\n" + $main
    }

    view source $dummy_closure
    | lines | skip | drop | to text
    | str replace --all '$command' $command
    | str replace --all '$file' $file
    | str replace --all '$dotnu_vars_delim' $"'($dotnu_vars_delim)'"
    | $"source ($file)\n\n($in)"
}

@example '' {
    [[a]; [b]] | table | comment-hash-colon
} --result '# => ╭─#─┬─a─╮
# => │ 0 │ b │
# => ╰───┴───╯
'
export def 'comment-hash-colon' [
    --source-code
] {
    let input = $in
    let closure = {|i|
        $i | into string | ansi strip | str trim --char "\n" | str replace --all --regex --multiline '^' "# => "
    }

    if $source_code {
        view source $closure
        | lines
        | skip
        | str replace '$i ' ''
        | drop
        | to text
    } else {
        do $closure $input
    }
}

# Extract captured output from a script file execution results
export def execute-and-parse-results [
    script: string
    --script_path: path
] {
    # Prints output that will be embedded back into the script
    let embed_in_script = {

        let input = table --expand
            | comment-hash-colon

        (capture-marker) + $input + "\n" + (capture-marker --close)
        | print
    }

    let embed_in_script_src = view source $embed_in_script
        | 'def embed-in-script [] ' + $in
        | str replace '(capture-marker --close)' $"'(capture-marker --close)'"
        | str replace 'capture-marker' $"'(capture-marker)'"
        | str replace 'comment-hash-colon' (comment-hash-colon --source-code)

    let script_updated = $script
        | lines
        | each {
            if $in !~ '^\s*#' {
                # don't search for `print $in` inside of commented lines
                str replace --regex $capture_point '| embed-in-script'
            } else { }
        }
        | prepend $embed_in_script_src
        | str join "\n"

    if $script_path != null { $script_path | path dirname | cd $in }

    ^$nu.current-exe -n -c $script_updated
    | parse --regex ('(?s)' + (capture-marker) + '(.*?)' + (capture-marker --close))
    # Parsing here presupposes capturing only the output of a script command,
    # so it won't be able to capture content inside custom command definitions correctly
    # (if they are executed more than once).
    | get capture0
}

# Finds capture-point lines (uncommented lines ending in `| print $in`)
export def find-capture-points [] {
    lines
    | where $it !~ '^\s*#' and $it =~ $capture_point
}

# Removes annotation lines starting with "# => " from the script
export def embeds-remove [] {
    normalize-newlines
    | lines
    | where not ($it starts-with "# => ")
    | str join "\n"
    | $in + "\n" # Explicit LF with trailing newline for Windows compatibility
}

export def capture-marker [
    --close
] {
    if not $close {
        "\u{200B}\u{200C}"
    } else {
        "\u{200C}\u{200B}"
    }
}

# Extract exported command names using AST
#
# Handles these patterns:
# - `export def cmd-name []` → cmd-name
# - `export use module.nu [cmd1 main]` → cmd1, module (item `main` names the submodule)
# - `export use module.nu` → module, plus `module <cmd>` for each of its exports
# - `export use module.nu *` → module (its main), plus its other exports as-is
#
# Bare and glob re-exports need the referenced file: they resolve relative to
# `base_dir` and recurse. Without `base_dir` (or a missing file) they degrade
# to the module stem alone — the re-exported subcommands can't be known.
export def extract-exported-commands [
    base_dir?: path # directory that `export use` paths are relative to
]: string -> list<string> {
    let tokens = ast --flatten $in | flatten span

    $tokens
    | enumerate
    | where item.content in ['export def' 'export use']
    | each {|match|
        let idx = $match.index
        if $match.item.content == 'export def' {
            # Command name is next token
            $tokens | get ($idx + 1) | get content | str trim --char "'" | str trim --char '"'
        } else {
            # export use: module path is next token, then optional item list
            let module_ref = $tokens
                | get ($idx + 1)
                | get content
                | str trim --char "'"
                | str trim --char '"'
            # importing a module's `main` yields a command named after the module
            let stem = $module_ref
                | path split
                | where $it != 'mod.nu'
                | last
                | str replace --regex '\.nu$' ''
            let items = $tokens
                | skip ($idx + 2)
                | take while { $in.shape in ['shape_string' 'shape_list'] }
                | where shape == 'shape_string'
                | get content
                | str trim --char '"'
                | str trim --char "'"

            if ($items | is-not-empty) and $items != ['*'] {
                $items | each { if $in == 'main' { $stem } else { } }
            } else if $base_dir == null {
                [$stem]
            } else {
                let target = $base_dir
                    | path join $module_ref
                    | if ($in | path type) == 'dir' { path join 'mod.nu' } else { }

                if not ($target | path exists) {
                    [$stem]
                } else {
                    open $target --raw
                    | extract-exported-commands ($target | path dirname)
                    | each {
                        if $in == 'main' {
                            $stem
                        } else if $items == ['*'] {
                            $in
                        } else {
                            $"($stem) ($in)"
                        }
                    }
                }
            }
        }
    }
    | flatten
}

# Complete AST output by filling gaps with synthetic tokens
#
# `ast --flatten` omits certain syntax elements (semicolons, assignment operators, etc).
# This command fills those gaps with synthetic tokens, providing complete byte coverage.
#
# Synthetic shapes added:
# - shape_semicolon: statement-ending `;`
# - shape_assignment: variable assignment `=` (with surrounding whitespace)
# - shape_whitespace: spaces, newlines between tokens
# - shape_newline: explicit newline characters
# - shape_pipe: pipe operator `|`
# - shape_comma: comma separator `,`
# - shape_dot: dot accessor `.`
# - shape_gap: unclassified gap content
@example 'Fill gaps in AST output' {
    'let x = 1;' | ast-complete | select content shape
} --result [[content shape]; [let shape_internalcall] [" " shape_whitespace] [x shape_vardecl] [" = " shape_assignment] [1 shape_int] [";" shape_semicolon]]
export def ast-complete []: string -> table {
    let source = $in
    let bytes = $source | encode utf8
    let tokens = ast --flatten $source | flatten span | sort-by start

    if ($tokens | is-empty) { return [] }

    let gaps = [{end: 0}] ++ $tokens ++ [{start: ($source | str length --utf-8-bytes)}]
        | window 2
        | where {|p| $p.0.end < $p.1.start }
        | each {|p|
            let content = $bytes | bytes at $p.0.end..<$p.1.start | decode utf8
            {content: $content start: $p.0.end end: $p.1.start shape: (classify-gap $content)}
        }

    $tokens | select content start end shape | append $gaps | sort-by start
}

# Classify gap content into synthetic shape types
def classify-gap [content: string]: nothing -> string {
    match ($content | str trim) {
        ";" => "shape_semicolon"
        "=" => "shape_assignment"
        "|" => "shape_pipe"
        "," => "shape_comma"
        "." => "shape_dot"
        "" => (if ($content =~ '\n') { "shape_newline" } else { "shape_whitespace" })
        _ => "shape_gap"
    }
}

# Split source code into individual statements using AST analysis
#
# Uses ast-complete to identify statement boundaries (semicolons and newlines
# at top level). Correctly handles nested blocks - newlines inside blocks don't
# create new statements.
#
# Returns a table with statement text and byte positions.
@example 'Split semicolon-separated statements' {
    'let x = 1; let y = 2' | split-statements | get statement
} --result ["let x = 1" "let y = 2"]
@example 'Split newline-separated statements' {
    "let a = 1\nlet b = 2" | split-statements | get statement
} --result ["let a = 1" "let b = 2"]
@example 'Preserve multi-line blocks as single statement' {
    "def foo [] {\n  1\n}" | split-statements | length
} --result 1
export def split-statements []: string -> table<statement: string, start: int, end: int> {
    let source = $in
    let bytes = $source | encode utf8
    let tokens = $source | ast-complete

    if ($tokens | is-empty) {
        return []
    }

    # Track block depth to identify top-level boundaries
    # Shapes that increase depth: shape_block "{", shape_closure "{", shape_signature "["
    # We only split on semicolons/newlines at depth 0
    mut depth = 0
    mut statements = []
    mut stmt_start = 0

    for token in $tokens {
        # Track block depth
        # Handle blocks where { and } may be in same token (e.g., "{}" or "{ x }")
        if $token.shape in ["shape_block" "shape_closure" "shape_gap"] {
            let opens = ($token.content | split row "{" | length) - 1
            let closes = ($token.content | split row "}" | length) - 1
            $depth = $depth + $opens - $closes
        }

        # Statement boundary at top level
        # Also check shape_gap that starts with newline (comments are bundled into gaps)
        let is_boundary = (
            $token.shape in ["shape_semicolon" "shape_newline"]
            or ($token.shape == "shape_gap" and ($token.content | str starts-with "\n"))
        )
        if $depth == 0 and $is_boundary {
            let stmt_text = $bytes | bytes at $stmt_start..<$token.start | decode utf8 | str trim
            if ($stmt_text | is-not-empty) {
                $statements = $statements | append {
                        statement: $stmt_text
                        start: $stmt_start
                        end: $token.start
                    }
            }
            $stmt_start = $token.end
        }
    }

    # Capture final statement
    let final_text = $bytes | bytes at $stmt_start..<($source | str length --utf-8-bytes) | decode utf8 | str trim
    if ($final_text | is-not-empty) {
        $statements = $statements | append {
                statement: $final_text
                start: $stmt_start
                end: ($source | str length --utf-8-bytes)
            }
    }

    $statements
}
