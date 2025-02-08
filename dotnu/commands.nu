
# Check .nu module files to determine which commands depend on other commands.
#
# > dependencies ...( glob tests/assets/module-say/say/*.nu )
# ╭─#─┬──caller──┬─filename_of_caller─┬──callee──┬─step─╮
# │ 0 │ hello    │ hello.nu           │          │    0 │
# │ 1 │ question │ ask.nu             │          │    0 │
# │ 2 │ say      │ mod.nu             │ hello    │    0 │
# │ 3 │ say      │ mod.nu             │ hi       │    0 │
# │ 4 │ say      │ mod.nu             │ question │    0 │
# │ 5 │ hi       │ mod.nu             │          │    0 │
# │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
# ╰───┴──────────┴────────────────────┴──────────┴──────╯
export def 'dependencies' [
    ...paths: path # paths to nushell module files
    --keep-builtins # keep builtin commands in the result page
    --definitions-only # output only commands' names definitions
] {
    let $callees_to_merge = $paths
        | each {
            extract-module-commands $in --keep-builtins=$keep_builtins --definitions-only=$definitions_only
        }
        | flatten

    if $definitions_only {return $callees_to_merge}

    generate {|i|
        if ( $i | is-not-empty ) {
            {
                out: $i,
                next: ( $i | join-next $callees_to_merge )
            }
        }
    } ($callees_to_merge | insert step 0)
    | flatten
    | uniq-by caller callee
}

# Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.
#
# > dependencies ...( glob tests/assets/module-say/say/*.nu ) | filter-commands-with-no-tests
# ╭─#─┬──caller──┬─filename_of_caller─╮
# │ 0 │ hello    │ hello.nu           │
# │ 1 │ question │ ask.nu             │
# │ 2 │ say      │ mod.nu             │
# ╰───┴──────────┴────────────────────╯
export def 'filter-commands-with-no-tests' [] {
    let $input = $in
    let $covered_with_tests = $input
        | where caller =~ 'test'
        | get callee
        | compact
        | uniq

    $input
    | reject callee step
    | uniq-by caller
    | where caller !~ 'test'
    | where caller not-in $covered_with_tests
}

# Parse commands definitions with their docstrings, output a table.
export def 'parse-docstrings' [
    $module_path? # path to a nushell module file
] {
    if $module_path == null { collect } else { $module_path | open | collect }
    | parse -r '(?:\n\n|^)(?<definit_line>(?:(?:#.*\n)*)?(?:export def.*))'
    | get definit_line
    | each {
        let $lines = lines

        let $command_name = $lines
            | last
            | extract-command-name $module_path

        let $blocks = $lines
            | if ( $lines | length ) > 1 {
                drop
                | str replace --all --regex '^#( ?)|( +$)' ''
                | split list ''
                | each {to text | $"( $in )\n"}
            } else {['']}

        let $command_description = $blocks.0
            | if $in =~ '(^|\n)>' { '' } else { str trim --char (char nl) }

        let $examples = $blocks
            | if $command_description == '' {} else { skip }
            | each {parse-example}
            | flatten

        {
            command_name: $command_name
            command_description: $command_description
            examples: $examples
            input: ( $lines | drop | to text )
        }
    }
}

# Execute examples in the docstrings of the module commands and update the results accordingly.
export def 'update-docstring-examples' [
    $module_path: path # path to a nushell module file
    --command-filter: string = '' # filter commands by their name to update examples at
    --use-statement: string = '' # use statement to execute examples with (like 'use module.nu').
                                 # Can be omitted to try to deduce automatically
    --echo # output script to stdout instead of updating the module_path provided
    --no-git-check # don't check for the emptiness of the working tree
] {
    if not ($no_git_check or $echo) { check-clean-working-tree $module_path }

    let $raw_module = open $module_path

    $raw_module
    | parse-docstrings
    | where command_name =~ $command_filter
    | execute-update-example-result --module-path $module_path --use-statement $use_statement
    | insert updated {|e| format-substitutions $e.examples $e.command_description}
    | select input updated
    | reduce -f $raw_module {|i| str replace -a $i.input $i.updated }
    | str replace -r '\n*$' "\n" # add ending new line
    | if $echo {} else { save $module_path --force }
}

# Open a regular .nu script. Divide it into blocks by "\n\n". Generate a new script
# that will print the code of each block before executing it, and print the timings of each block's execution.
#
# > set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | to text
# mut $prev_ts = date now
# print ( "> sleep 0.5sec" | nu-highlight )
# sleep 0.5sec
export def 'set-x' [
    file: path # path to `.nu` file
    --regex: string = "\n+\n" # regex to use to split .nu on blocks
    --echo # output script to terminal
] {
    let $out_file = $file | str replace -r '(\.nu)?$' '_setx.nu'

    open $file
    | str trim --char ( char nl )
    | split row -r $regex
    | each {|block|
        $block
        | escape-for-quotes
        | ('print ("> ' + $in + '" | nu-highlight)' + (char nl) + $block
            + "\nprint $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);\n\n")
    }
    | prepend 'mut $prev_ts = ( date now )'
    | to text
    | if $echo { return $in } else {
        save -f $out_file

        print $'the file ( $out_file ) is produced. Source it'
        commandline edit -r $'source ( $out_file )'
    }
}

# Generate nupm tests from examples in docstrings
export def 'generate-nupm-tests' [
    $module_path: path # path to a nushell module file
    --echo # output script to stdout instead of updating the module_path provided
] {
    let $module_path = $module_path | path expand
    let $root = find-root ( $module_path | if ( $in | path type ) == file {path dirname} else {} )
    let $relative_module_path = $module_path
        | path relative-to $root
        | [.. $in]
        | path join
        | $'use ( $in ) *'

    let $tests_script = parse-docstrings $module_path
        | select command_name examples
        | where examples != []
        | each {|i|
            $i.examples
            | enumerate
            | each {|e| generate-test-command $i.command_name $e.index $e.item.command}
        }
        | flatten
        | prepend $relative_module_path
        | str join "\n\n"
        | str replace -r "\n*$" "\n"

    if $echo {return $tests_script}

    let $tests_filename = $'dotnu-examples-test-( $module_path | path basename )'
    let $tests_path = [ $root 'tests' $tests_filename ] | path join
    let $tests_path_abs = $tests_path | path expand
    let $tests_mod_path = $tests_path | str replace $tests_filename 'mod.nu'
    let $export_statement = $"export use ( $tests_filename ) *\n"

    mkdir ( $root | path join 'tests' )
    $tests_script | save -f $tests_path_abs

    if ( $tests_mod_path | path exists ) {
        open $tests_mod_path
        | if ( $in | str contains $tests_filename ) {
            return
        } else {
            $"( $in )\n( $export_statement )"
        }
    } else {
        $export_statement
    }
    | save -f $tests_mod_path
}

# Generate `.numd` from `.nu` divided on blocks by "\n\n"
export def 'generate-numd' [] {
    split row -r "\n+\n"
    | each {$"```nu\n( $in )\n```\n"}
    | to text
}

# Extract a code of a command from a module and save it as a `.nu` file that can be sourced.
# By executing this `.nu` file, you'll have all variables in your environment for debugging or development.
export def 'extract-command-code' [
    $module_path: path # path to a nushell module file
    $command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save extracted command script
    --clear-vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
    --set-vars: record = {} # set variables for a command
    --code-editor = 'code' # code is my editor of choice to open the result file
] {
    let $command = $command
        | if $in =~ '\s' and $in !~ "^(\"|')" {
            $'"( $in )"'
        } else {}

    let $dotnu_vars_delim = '#dotnu-vars-end'

    let $extracted_command = dummy-command $command $module_path $dotnu_vars_delim
        | nu -n -c $in
        | split row $dotnu_vars_delim

    if $extracted_command.1? == null {
        error make --unspanned {msg: $'no command `( $command )` was found'}
    }

    let $filename = $output
        | default $'( $command | str trim -c '"' | str trim -c "'" ).nu'

        # here we use defined variables from the previously extracted command to a file
    let $variables_from_prev_script = if ( $filename | path exists ) and not $clear_vars {
            open $filename
            | split row $dotnu_vars_delim
            | get 0
            | variable-definitions-to-record
        } else { {} }

    $extracted_command.0
    | variable-definitions-to-record
    | merge $variables_from_prev_script
    | merge $set_vars
    | items {|k v| $'let $( $k ) = ( $v | to nuon )' }
    | prepend $'source ( $module_path )'
    | append $dotnu_vars_delim
    | append $extracted_command.1
    | to text
    | if $echo {
        return $in
    } else {
        save -f $filename

        $" ^( $code_editor ) \"( $filename )\"; commandline edit --replace ' source \"( $filename )\"'"
        | commandline edit --replace $in
    }
}

# todo: `list-main-commands` should be a completion for nushell cli

export def 'list-main-commands' [
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
        where $it =~ '^( export )?def '
        | extract-command-name
        | where $it starts-with 'main'
        | str replace 'main ' ''
    }
    | if ( $in | is-empty ) {
        print 'No command found'
        return
    } else {}
    | input list --fuzzy "Choose a command"
    | if $in == 'main' { '' } else {}
    | if $export {
        $"use ( $path ) '( $in )'; ( $in )"
    } else {
        $"nu ( $path ) ( $in )"
    }
    | commandline edit -r $in
}

#todo: make configuration like --autocommit in file itself

# Inserts captured output back into the script at capture points
export def 'embeds-update' [
    file?: path
] {
    let $input = $in

    if $input == null and $file == null {
        error make {msg: 'pipe in a script or provide a path'}
    }

    let $script = if $input == null { open $file } else { $input }
        | embeds-remove

    let $results = execute-and-parse-results $script

    let $replacements = $script
        | find-capture-points
        | zip $results

    $replacements
    | reduce --fold $script {|it| str replace $it.0 ($it.0 + "\n" + $it.1)}
    | str replace -ar '\n{3,}' "\n\n"
    | str replace -r "\n*$" "\n"
    | if $input == null {save -f $file} else {}
}

export def 'capture start' [] {}

export def --env 'embeds-setup' [
    $path?: path
    --auto-commit
] {
    $env.dotnu.path = (
        $path
        | if $in == null {
            get-dotnu-capture-path
        } else {
            str replace -r '(\.nu)?$' '.nu' # make sure that the script has .nu extension
        }
        | path expand
    )

    if $auto_commit {
        touch $env.dotnu.path

        git-autocommit-dotnu-capture

        $env.dotnu.auto-commit = true
    }

}

export def 'embed-add' [
    --pipe-further (-p) # output input further to the pipeline
    --published # output the published representation into terminal
    --dry_run
    #todo: --
] {
    let $input = $in

    let $path = get-dotnu-capture-path

    let $command = if $input == null {
        get-last-command
    } else {
        get-last-command --index 1
        | str replace -r '(?s)\| ?dotnu embed-add.*$' ''
    }

    let $input_table = $input
        | if $in == null {} else {
            table -e --width 160
            | comment-hash-colon
            | $"\n($in)\n"
        }

    # $"\n($command) | print $in\n($input_table)"

    let $script_with_output = ''
        | append $command
        | append ' | print $in'
        | append $input_table
        | to text


    if $env.dotnu?.auto-commit? == true {
        git-autocommit-dotnu-capture
    }

    if not $dry_run {$script_with_output | save -a $path }

    if $published { return $script_with_output }
    if $pipe_further or $dry_run { return $input }
}
#### helpers
# they used to be separately here from the main code, but I want to experiment with structure
# so all the commands are in one file now, and all are exported, to be availible in my scripts
# that can use this file commands with 'use ..', though main commands are exported in mod.nu

export def 'get-dotnu-capture-path' [] {
    $env.dotnu?.path? | default dotnu-capture.nu
}

export def 'git-autocommit-dotnu-capture' [] {
    let $path = get-dotnu-capture-path

    git add $path
    git commit --only $path -m 'dotnu capture autocommit'
}

export def 'get-last-command' [
    --index: int = 2
] {
    history | last $index | first | get command
}

export def check-clean-working-tree [
    $module_path: path
] {
    cd ( $module_path | path dirname )

    let git_status = git status --short

    $git_status
    | lines
    | parse '{s} {m} {f}'
    | where f =~ $'( $module_path | path basename )$'
    | is-not-empty
    | if $in {
        error make --unspanned {
            msg: ( "Working tree isn't empty. Please commit or stash changed files, " +
                    "or use `--no-git-check` flag. Uncommited files:\n" + $git_status )
        }
    }
}

# make a record from code with variable definitions
#
# > "let $quiet = false; let $no_timestamp = false" | variable-definitions-to-record | to nuon
# {quiet: false, no_timestamp: false}
#
# > "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record | to nuon
# {a: b, c: d}
#
# > "let $a = null" | variable-definitions-to-record | to nuon
# {a: null}
#
# > "" | variable-definitions-to-record | to nuon
# {}
export def variable-definitions-to-record []: string -> record {
    let $script_with_variables_definitnions = str replace -a ';' ";\n"
        | $in + ( char nl )

    let $variables_record = $script_with_variables_definitnions
        | parse -r 'let ( ?:\$ )?( ?<var>.* ) ='
        | get var
        | uniq
        | each {$'( $in ): $( $in )'}
        | str join ' '
        | '{' + $in + '} | to nuon' # this way we ensure the proper formatting for bool, numeric and string vars

    let $script = $script_with_variables_definitnions + $variables_record

    nu -n -c $script | from nuon
}

# parse `>` examples from the parsed docstrings
export def parse-example [] {
    parse -r (
        '(?<annotation>^(?:[^\n>]*\n)+)??' +
        '(?<command>' +
            '> (?:[^\n]*\n)' +
            '(?:(?:\||;|>)[^\n]*\n)*' +
        ')' +
        '(?s)(?<result>.*)?'
    )
    | str trim --char ( char nl ) annotation command result
}

# > 'export def --env "test" --wrapped' | lines | last | extract-command-name
# test
export def 'extract-command-name' [
    $module_path? # path to a nushell module file
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
    let $input = $in
    let $module_name = $path
        | path expand
        | path split
        | where $it != mod.nu
        | last
        | str replace -r '\.nu$' ' '

    $input
    | str replace -r '^main( |$)' $module_name
    | str trim
}

# generate command to execute `>` example command in a new nushell instance
# in case of any problems - use `--use-statement` flag
export def gen-example-exec-command [
    $example_command
    $command_name
    $use_statement
    $module_path
] {
    let $module_stem = $module_path | path parse | get stem

    # the logic to deduce the use statement is very fragile and are better to be remade
    if $use_statement != '' {
        $use_statement
    } else if ( $example_command | str contains $'( $module_stem ) ( $command_name )' ) {
        $'use "( $module_path )"'
    } else if $module_stem == 'mod' {
        $'use "( $module_path | path dirname )" *'
    } else {
        $'use "( $module_path )" *'
    }
    | $"( $in );\n( $example_command )"
}

# Escapes symbols to be printed unchanged inside a `print "something"` statement.
#
# > 'abcd"dfdaf" "' | escape-for-quotes
# abcd\"dfdaf\" \"
export def escape-for-quotes []: string -> string {
    str replace --all --regex '(\\|\")' '\$1'
}

# context aware completions for defined command names in nushell module files
#
# > nu-completion-command-name 'dotnu extract-command-code tests/assets/b/example-mod1.nu' | first 3
# ╭───┬───────────╮
# │ 0 │ main      │
# │ 1 │ lscustom  │
# │ 2 │ command-5 │
# ╰───┴───────────╯
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
#
# > extract-module-commands tests/assets/b/example-mod1.nu | first 3
# ╭───┬───────────┬───────────────┬────────────────────╮
# │ # │  caller   │    callee     │ filename_of_caller │
# ├───┼───────────┼───────────────┼────────────────────┤
# │ 0 │ command-5 │ command-3     │ example-mod1.nu    │
# │ 1 │ command-5 │ first-custom  │ example-mod1.nu    │
# │ 2 │ command-5 │ append-random │ example-mod1.nu    │
# ╰───┴───────────┴───────────────┴────────────────────╯
#
# > extract-module-commands --definitions-only tests/assets/b/example-mod1.nu | first 3
# ╭───┬──────────────┬────────────────────╮
# │ # │    caller    │ filename_of_caller │
# ├───┼──────────────┼────────────────────┤
# │ 0 │ example-mod1 │ example-mod1.nu    │
# │ 1 │ lscustom     │ example-mod1.nu    │
# │ 2 │ command-5    │ example-mod1.nu    │
# ╰───┴──────────────┴────────────────────╯
export def extract-module-commands [
    path: path # path to a .nu module file.
    --keep-builtins # keep builtin commands in the result page
    --definitions-only # output only commands' names definitions
] {
    let $raw_script = open $path -r

    let $defined_commands = $raw_script
        | lines
        | where $it =~ '^(export )?def.*\['
        | wrap line
        | insert caller {|i|
            $i.line
            | extract-command-name
            | replace-main-with-module-name $path
        }
        | insert filename_of_caller ( $path | path basename )

    if $definitions_only or ( $defined_commands | is-empty ) {
        return ( $defined_commands | select caller filename_of_caller )
    }

    let $with_index = $defined_commands
        | insert start {|i| $raw_script | str index-of $i.line}

    let $dependencies = nu --ide-ast $path
        | from json
        | flatten span
        | join $with_index start -l
        | merge (
            $in
            | select caller filename_of_caller
            | scan {} --noinit {|curr prev| if $curr.caller? == null {$prev} else {$curr}}
        )
        | where shape in ['shape_internalcall' 'shape_external']
        | if $keep_builtins {} else {
            where content not-in (
                help commands | where command_type in ['built-in' 'keyword'] | get name
            )
        }
        | select caller content filename_of_caller
        | rename --column {content: callee}
        | where caller != null

    let $commands_with_no_deps = $defined_commands
        | select caller filename_of_caller
        | where caller not-in ( $dependencies.caller | uniq )
        | insert callee null

    $dependencies | append $commands_with_no_deps
}

# update examples column with results of execution commands
export def execute-update-example-result [
    --module-path: string = ''
    --use-statement: string = ''
] {
    update examples {|row|
        $row.examples
        | upsert result {|i|
            let $example_command = $i.command
                | str replace -arm '^> ' ''
                | gen-example-exec-command $in $row.command_name $use_statement $module_path

            nu --no-newline --commands $example_command
            | complete
            | if $in.exit_code == 0 {get stdout} else {
                print $"the next command has failed:\n`( $example_command )`\n\n( $in.stderr )"
                'example update failed'
            }
            | ansi strip
            | str trim --char ( char nl )
        }
    }
}

# prepare pairs of substituions of old results and new results
export def format-substitutions [
    $examples
    $command_description
] {
    $examples
    | each {|i|
        [ $i.annotation $i.command $i.result ]
        | compact --empty
        | str join ( char nl ) # `to text` produces trailing empty line
    }
    | prepend $command_description
    | compact --empty
    | str join $"( char nl )( char nl )"
    | lines
    | each {$"# ( $in )" | str trim}
    | to text
}

# helper function for use inside of generate
#
# > [[caller callee step filename_of_caller]; [a b 0 test] [b c 0 test]] | join-next $in | to nuon
# [[caller, callee, step, filename_of_caller]; [a, c, 1, test]]
export def 'join-next' [
    callees_to_merge
] {
    join -l $callees_to_merge callee caller
    | select caller callee_ step filename_of_caller
    | rename caller callee
    | upsert step {|i| $i.step + 1}
    | where callee != null
}

export def 'dummy-command' [
    $command
    $file
    $dotnu_vars_delim
] {
    # the closure below is used as highlighted in an editor constructor
    # for the command that will be executed in `nu -c`
    let $dummy_closure = {|function|
        let $params = scope commands
            | where name == $command
            | get -i signatures.0
            | if $in == null {
                error make --unspanned { msg: 'no command $command was found' }
            } else {}
            | values
            | get 0
            | each {
                if ( $in.parameter_type == 'rest' ) {
                    if ( $in.parameter_name == '' ) {
                        # if rest parameters named $rest, in the signatures it doesn't have a name
                        upsert parameter_name 'rest'
                    } else {}
                    | default [] parameter_default
                } else {}
            }
            | where parameter_name != null
            | each {|i|
                let $param = $i.parameter_name | str replace -a '-' '_' | str replace '$' ''

                let $value = $i.parameter_default?
                    | default ( if $i.parameter_type == 'switch' { false } )
                    | to nuon # to handle nuls

                $"let $( $param ) = ( $value ) # ( $i.syntax_shape )"
            }
            | to text

        let $main = view source $command
            | lines
            | upsert 0 {|i| '# ' + $i}
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

export def generate-test-command [
    $command_name
    $index
    $command
] {
    [
        $'export def `( $command_name )-( $index )-test` [] {'
            ( $command | str replace -arm `^( > )?` `    ` )
        '}'
    ] | to text
}

export def 'comment-hash-colon' [
    --source-code
] {
    let $input = $in
    let $closure = {|i| $i |
        into string | ansi strip | str trim -c "\n" | str replace -arm '^' '#: '
    }

    if $source_code {
        view source $closure
        | lines
        | skip
        | drop
        | to text
    } else {
        do $closure $input
    }
}

# Extracts captured output from a script file execution result
export def execute-and-parse-results [
    script: string
] {
    # Prints output that will be embedded back into the script
    let embed_in_script = {
        let $input = table -e
            | comment-hash-colon

        capture-marker
        | append $input
        | append (capture-marker --close)
        | to text
        | print
    }

    let $embed_in_script_src = view source $embed_in_script
        | 'def embed-in-script [] ' + $in
        | str replace 'capture-marker' $"'(capture-marker)'"
        | str replace '(capture-marker --close)' $"'(capture-marker --close)'"
        | str replace 'comment-hash-colon' (comment-hash-colon --source-code)

    let $script_upd = $script
        | lines
        | each {
            if $in !~ '^\s*#' { # don't search for `print $in` inside of commented lines
                str replace -r '\| *print +\$in *' '| embed-in-script'
            } else {}
        }
        | prepend $embed_in_script_src
        | to text

    ^$nu.current-exe --config $nu.config-path --env-config $nu.env-path -c $script_upd
    | ansi strip
    | parse -r ( '(?s)' + (capture-marker) + '(.*?)' + (capture-marker --close) )
    | get capture0
}

# Finds lines where embed-in-script is used in the script
export def find-capture-points [] {
    lines
    | where $it !~ '^\s*#' and $it =~ '\|\s?print \$in *$'
}

# Removes annotation lines starting with '#:' from the script
export def embeds-remove [] {
    lines
    | where not ($it starts-with '#:')
    | to text
}


def capture-marker [
    --close
] {
    if not $close {
        "\u{200B}\u{200C}"
    } else {
        "\u{200C}\u{200B}"
    }
}

# I hardcode scan from 0.101 version here, as there were a breaking change
# to give chance for execution in previous untested nushell versions

# Returns a list of intermediate steps performed by `reduce`
# (`fold`). It takes two arguments, an initial value to seed the
# initial state and a closure that takes two arguments, the first
# being the list element in the current iteration and the second
# the internal state.
# The internal state is also provided as pipeline input.
#
# # Example
# ```
# use std ["assert equal" "iter scan"]
# let scanned = ([1 2 3] | iter scan 0 {|x, y| $x + $y})
#
# assert equal $scanned [0, 1, 3, 6]
#
# # use the --noinit(-n) flag to remove the initial value from
# # the final result
# let scanned = ([1 2 3] | iter scan 0 {|x, y| $x + $y} -n)
#
# assert equal $scanned [1, 3, 6]
# ```
export def scan [ # -> list<any>
    init: any            # initial value to seed the initial state
    fn: closure          # the closure to perform the scan
    --noinit(-n)         # remove the initial value from the result
] {
    reduce --fold [$init] {|it, acc|
        let acc_last = $acc | last
        $acc ++ [($acc_last | do $fn $it $acc_last)]
    }
    | if $noinit { skip } else { }
}
