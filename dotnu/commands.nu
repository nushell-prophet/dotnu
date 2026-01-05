use std/iter scan

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

    generate {|i|
        if ($i | is-not-empty) {
            {
                out: $i
                next: ($i | join-next $callees_to_merge)
            }
        }
    } ($callees_to_merge | insert step 0)
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
    let out_file = $file | str replace -r '(\.nu)?$' '_setx.nu'

    open $file
    | if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
    | str trim --char (char nl)
    | split row -r $regex
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
        save -f $out_file

        if not $quiet {
            print $'the file ($out_file) is produced. Source it'
        }
        commandline edit -r $'source ($out_file)'
    }
}

# Generate `.numd` from `.nu` divided into blocks by "\n\n"
export def 'generate-numd' [] {
    split row -r "\n+\n"
    | each { $"```nu\n($in)\n```\n" }
    | to text
}

# Extract command code from a module and save it as a `.nu` file that can be sourced.
# By executing this `.nu` file, you'll have all the variables in your environment for debugging or development.
export def 'extract-command-code' [
    $module_path: path # path to a Nushell module file
    $command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save the extracted command script
    --clear-vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
    --set-vars: record = {} # set variables for a command
    --code-editor = 'code' # code is my editor of choice to open the result file
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
    | default $'($command | str trim -c '"' | str trim -c "'").nu'

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
        save -f $filename

        $" ^($code_editor) \"($filename)\"; commandline edit --replace ' source \"($filename)\"'"
        | commandline edit --replace $in
    }
}

# todo: `list-exported-commands` should be a completion for Nushell CLI

export def 'list-exported-commands' [
    $path: path
    --export # use only commands that are exported
] {
    open $path -r
    | lines
    | if $export {
        where $it =~ '^export def '
        | extract-command-name
        | replace-main-with-module-name $path
    } else {
        where $it =~ '^(export )?def '
        | extract-command-name
        | where $it starts-with 'main'
        | str replace 'main ' ''
    }
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
    | if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
    | embeds-remove

    let results = execute-and-parse-results $script --script_path=$file

    let replacements = $script
    | find-capture-points
    | zip $results

    let prevent_second_replacement = " # to-not-be-replaced-again"

    $replacements
    | reduce --fold $script {|it|
        str replace ("\n" + $it.0 + "\n") ("\n" + $it.0 + $prevent_second_replacement + "\n" + $it.1 + "\n")
    }
    | str replace -a $prevent_second_replacement ''
    | str replace -ar '\n{3,}' "\n\n"
    | str replace -r "\n*$" "\n"
    | if $echo or ($input != null) { } else { save -f $file }
}

# Execute @example blocks and update their --result values
# Similar to embeds-update but for @example attributes
export def 'examples-update' [
    file: path # path to .nu file with @example blocks
    --echo # output updates to stdout instead of saving
] {
    let content = open $file
    | if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }

    let examples = $content | find-examples

    if ($examples | is-empty) {
        if $echo { return $content }
        return
    }

    # Execute each example and collect results
    let results = $examples | each {|ex|
        let result = execute-example $ex.code $file
        {
            original: $ex.original
            result_line: $ex.result_line
            new_result: $result
        }
    }

    # Replace each example's result line
    let updated = $results | reduce --fold $content {|item acc|
        let old_result_line = $item.result_line
        let new_result_line = $"} --result ($item.new_result)"

        $acc | str replace $old_result_line $new_result_line
    }

    $updated
    | if $echo { } else { save -f $file }
}

# Find @example blocks with their code and result sections
def find-examples []: string -> table<original: string, code: string> {
    let content = $in
    let lines = $content | lines

    # Find lines with "} --result" pattern (single-line results only)
    $lines
    | enumerate
    | where {|row| $row.item =~ '^\} --result [^\n]+$' and $row.item !~ "^\\} --result '" }
    | each {|row|
        let result_line_idx = $row.index
        let result_line = $row.item

        # Look backwards to find the @example line
        let example_start = $lines
        | take $result_line_idx
        | enumerate
        | where {|r| $r.item =~ '^@example ' }
        | last
        | get index

        # Extract code lines between @example and } --result
        let code_lines = $lines
        | skip ($example_start + 1)
        | take ($result_line_idx - $example_start - 1)
        | str join "\n"
        | str trim

        # Build original block for replacement
        let original_block = $lines
        | skip $example_start
        | take ($result_line_idx - $example_start + 1)
        | str join "\n"

        {
            original: $original_block
            code: $code_lines
            result_line: $result_line
        }
    }
    | where {|row| $row.code != '' }
}

# Execute example code and return the result as nuon
def execute-example [code: string file: path]: nothing -> string {
    let abs_file = $file | path expand
    let dir = $abs_file | path dirname
    let parent_dir = $dir | path dirname
    let module_name = $dir | path basename

    # Strip module prefix from code if present (e.g., "dotnu dependencies" -> "dependencies")
    let normalized_code = $code | str replace -r $'^($module_name) ' ''

    # Build script: cd to parent, source file directly to access all functions
    let script = $"
        cd '($parent_dir)'
        source '($abs_file)'
        ($normalized_code) | to nuon
    "

    try {
        ^$nu.current-exe -n -c $script
        | str trim
    } catch {|e|
        $"error: ($e.msg)"
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
            str replace -r '(\.nu)?$' '.nu' # make sure that the script has .nu extension
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
        | str replace -r '(?s)\| ?dotnu embed-add.*$' ''
    }

    let input_table = $input
    | if $in == null { } else {
        table -e --width 160
        | comment-hash-colon
        | $"\n($in)\n"
    }

    let script_with_output = $"\n($command) | print $in\n($input_table)"

    if $env.dotnu?.auto-commit? == true {
        git-autocommit-dotnu-capture
    }

    if not $dry_run { $script_with_output | save -a $path }

    if $published { return $script_with_output }
    if $pipe_further or $dry_run { return $input }
}

# start capturing commands and their outputs into a file
export def --env 'embeds-capture-start' [
    file: path = 'dotnu-capture.nu'
]: nothing -> nothing {
    cprint $'dotnu commands capture has been started.
        Commands and their outputs of the current nushell instance
        will be appended to the *($file)* file.

        Beware that your `display_output` hook has been changed.
        It will be reverted when you use `dotnu embeds-capture-stop`'

    $env.dotnu.status = 'running'
    $env.dotnu.embeds-capture-path = ($file | path expand)

    $env.backup.hooks.display_output = (
        $env.config.hooks?.display_output?
        | if $in == null {
            if (term size).columns >= 100 { table -e } else { table }
        } else { }
    )

    $env.config.hooks.display_output = {
        let input = $in
        let command = get-command-from-hist | get current

        $input
        | default ''
        | if (term size).columns >= 100 { table -e } else { table }
        | into string
        | ansi strip
        | if $in == '' { $"\n($command)\n" } else {
            comment-hash-colon
            | $"\n($command) | print $in\n($in)\n\n"
        }
        | str replace --regex "\n{3,}$" "\n\n"
        | if ($in !~ 'dotnu capture') {
            # don't save dotnu capture managing commands
            save --append --raw $env.dotnu.embeds-capture-path
        }

        print -n $input # without the `-n` flag new line is added to an output
    }
}

# stop capturing commands and their outputs
export def --env 'embeds-capture-stop' []: nothing -> nothing {

    if $env.dotnu?.status? != 'running' {
        cprint "dotnu capture hasn't been active"
        return
    }

    $env.config.hooks.display_output = $env.backup.hooks.display_output

    let file = $env.dotnu.embeds-capture-path

    cprint $'dotnu commands capture to the *($file)* file has been stopped.'

    $env.dotnu.status = 'stopped'
}

#### helpers
# they used to be separate from the main code, but I want to experiment with structure
# so all the commands are in one file now, and all are exported, to be available in my scripts
# that can use this file commands with 'use ..', though main commands are exported in mod.nu

export def 'get-dotnu-capture-path' [] {
    $env.dotnu?.embeds-capture-path? | default dotnu-embeds-capture.nu
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
    $module_path: path
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
    let script_with_variables_definitnions = str replace -a ';' ";\n"
    | if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
    | $in + (char nl)

    let parsed_vars = $script_with_variables_definitnions
    | parse -r 'let \$?(?<var>.*) ='

    if ($parsed_vars | is-empty) {
        return {}
    }

    let variables_record = $parsed_vars
    | get var
    | uniq
    | each { $'($in): $($in)' }
    | str join ' '
    | '{' + $in + '} | to nuon' # this way we ensure the proper formatting for bool, numeric and string vars

    let script = $script_with_variables_definitnions + $variables_record

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
    module_path? # path to a nushell module file
] {
    str replace -r '\[.*' ''
    | str replace -r '^(export )?def ' ''
    | str replace -ra '(--(env|wrapped) ?)' ''
    | str replace -ra "\"|'|`" ''
    | str trim
}

export def replace-main-with-module-name [
    $path
] {
    let input = $in
    let module_name = $path
    | path expand
    | path split
    | where $it != mod.nu
    | last
    | str replace -r '\.nu$' ' '

    $input
    | str replace -r '^main( |$)' $module_name
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
    $context | str replace -r '^.*? extract-command-code ' ''
    | str trim | split row ' ' | first
    | path expand | open $in -r | lines
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
    let script_content = open $module_path -r
    let code_bytes = $script_content | encode utf-8
    let all_tokens = ast --flatten $script_content | flatten span

    # Phase 1a: Find def statements using line-based parsing
    # (line parsing works fine for def, and we need byte offsets for range lookup)
    let lines_pos = $script_content
    | lines
    | reduce --fold {offset: 0 lines: []} {|line acc|
        let entry = {line: $line start: $acc.offset}

        {
            offset: ($acc.offset + ($line | str length -b) + 1)
            lines: ($acc.lines | append $entry)
        }
    }
    | get lines

    let def_definitions = $lines_pos
    | insert caller {
        if $in.line =~ '^(export )?def .*\[' {
            $in.line | extract-command-name | replace-main-with-module-name $module_path
        }
    }
    | where caller != null
    | select caller start

    # Phase 1b: Find attributes using AST (prevents false positives from @attr inside strings)
    # Real attributes have '@' immediately before the token in source
    let attribute_definitions = $all_tokens
    | where {|t|
        $t.start > 0 and (($code_bytes | bytes at ($t.start - 1)..<($t.start) | decode utf-8) == '@')
    }
    | insert caller {|t| '@' + ($t.content | split row ' ' | first) } # '@complete external' → '@complete'
    | select caller start

    let defined_defs = $def_definitions
    | append $attribute_definitions
    | insert filename_of_caller ($module_path | path basename)

    if $definitions_only or ($defined_defs | is-empty) {
        return ($defined_defs | select caller filename_of_caller)
    }

    let defs_with_index = $defined_defs | sort-by start

    # Range-based lookup: exact join fails because def positions != AST token positions
    let calls = $all_tokens
    | each {|token|
        let def = $defs_with_index | where start <= $token.start | last
        if $def == null {
            $token | insert caller null | insert filename_of_caller null
        } else {
            $token | insert caller $def.caller | insert filename_of_caller $def.filename_of_caller
        }
    }
    | where caller != null and caller !~ '^@' # exclude tokens inside attribute blocks
    | where shape in ['shape_internalcall' 'shape_external']
    | where content not-in (help commands | where command_type == 'keyword' | get name) # always exclude keywords (def, export def, etc.)
    | if $keep_builtins { } else {
        where content not-in (help commands | where command_type == 'built-in' | get name)
    }
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
    let script_content = open $module_path -r

    $script_content
    | lines
    | wrap line
    | insert command {|i|
        if $i.line =~ '^(export )?def ' {
            $i.line
            | extract-command-name
            | replace-main-with-module-name $module_path
        } else { null }
    }
    | merge (
        $in.command
        | scan --noinit null {|i acc|
            if $i == null { $acc } else { $i }
        }
        | wrap command
    )
    | group-by command
    | items {|k v|
        $v.line | reverse | skip until {|i| $i == '}' }
        | reverse
        | to text
        | {$k: $in}
    }
    | into record
}

# prepare pairs of substitutions of old results and new results
export def format-substitutions [
    $examples
    $command_description
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
    callees_to_merge
] {
    join -l $callees_to_merge callee caller
    | select caller callee_ step filename_of_caller
    | rename caller callee
    | upsert step {|i| $i.step + 1 }
    | where callee != null
}

export def 'dummy-command' [
    $command
    $file
    $dotnu_vars_delim
] {
    # the closure below is used as highlighted in an editor constructor
    # for the command that will be executed in `nu -c`
    let dummy_closure = {|function|
        let params = scope commands
        | where name == $command
        | get -o signatures.0
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
            let param = $i.parameter_name | str replace -a '-' '_' | str replace '$' ''

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
    | str replace -a '$command' $command
    | str replace -a '$file' $file
    | str replace -a '$dotnu_vars_delim' $"'($dotnu_vars_delim)'"
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
        $i | into string | ansi strip | str trim -c "\n" | str replace -arm '^' "# => "
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

        let input = table -e
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
            str replace -r '\| *print +\$in *' '| embed-in-script'
        } else { }
    }
    | prepend $embed_in_script_src
    | str join "\n"

    if $script_path != null { $script_path | path dirname | cd $in }

    ^$nu.current-exe -n -c $script_updated
    | ansi strip
    | parse -r ('(?s)' + (capture-marker) + '(.*?)' + (capture-marker --close))
    # Parsing here presupposes capturing only the output of a script command,
    # so it won't be able to capture content inside custom command definitions correctly
    # (if they are executed more than once).
    | get capture0
}

# Finds lines where embed-in-script is used in the script
export def find-capture-points [] {
    lines
    | where $it !~ '^\s*#' and $it =~ '\|\s?print \$in *$'
}

# Removes annotation lines starting with "# => " from the script
export def embeds-remove [] {
    if $nu.os-info.family == windows { str replace --all (char crlf) "\n" } else { }
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
    let source_len = $source | str length -b
    let tokens = ast --flatten $source | flatten span | sort-by start

    if ($tokens | is-empty) {
        return []
    }

    # Find gaps between consecutive tokens
    let inter_gaps = $tokens
    | window 2
    | each {|pair|
        let gap_start = $pair.0.end
        let gap_end = $pair.1.start
        if $gap_start < $gap_end {
            let gap_content = $bytes | bytes at $gap_start..<$gap_end | decode utf8
            {
                content: $gap_content
                start: $gap_start
                end: $gap_end
                shape: (classify-gap $gap_content)
            }
        }
    }
    | compact

    # Check for leading gap (before first token)
    let first_token = $tokens | first
    let leading_gap = if $first_token.start > 0 {
        let gap_content = $bytes | bytes at 0..<($first_token.start) | decode utf8
        [{
            content: $gap_content
            start: 0
            end: $first_token.start
            shape: (classify-gap $gap_content)
        }]
    } else { [] }

    # Check for trailing gap (after last token)
    let last_token = $tokens | last
    let trailing_gap = if $last_token.end < $source_len {
        let gap_content = $bytes | bytes at ($last_token.end)..<$source_len | decode utf8
        [{
            content: $gap_content
            start: $last_token.end
            end: $source_len
            shape: (classify-gap $gap_content)
        }]
    } else { [] }

    # Combine all tokens and gaps, sorted by position
    $leading_gap
    | append $inter_gaps
    | append $trailing_gap
    | append ($tokens | select content start end shape)
    | sort-by start
}

# Classify gap content into synthetic shape types
def classify-gap [content: string]: nothing -> string {
    let trimmed = $content | str trim
    match $trimmed {
        ";" => "shape_semicolon"
        "=" => "shape_assignment"
        "|" => "shape_pipe"
        "," => "shape_comma"
        "." => "shape_dot"
        "" => {
            # Pure whitespace - check if it contains newlines
            if ($content =~ '\n') {
                "shape_newline"
            } else {
                "shape_whitespace"
            }
        }
        _ => {
            # Check for assignment with surrounding whitespace
            if ($trimmed == "=" and $content =~ '^\s*=\s*$') {
                "shape_assignment"
            } else {
                "shape_gap"
            }
        }
    }
}
