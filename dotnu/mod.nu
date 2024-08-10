use dotnu-internals.nu [
    dummy-command
    escape-escapes
    execute-update-example-results
    extract-command-name
    extract-module-commands
    generate-test-command
    join-next
    nu-completion-command-name
    parse-example
    prepare-substitutions
    variable-definitions-to-record
]

# Open a regular .nu script. Divide it into blocks by "\n\n". Generate a new script
# that will print the code of each block before executing it, and print the timings of each block's execution.
#
# > set-x tests/assets/set-x-demo.nu --echo | lines | first 3 | str join (char nl)
# mut $prev_ts = date now
# print ("> sleep 0.5sec" | nu-highlight)
# sleep 0.5sec
export def set-x [
    file: path # path to `.nu` file
    --regex: string = "\n+\n" # regex to use to split .nu on blocks
    --echo # output script to terminal
] {
    let $out_file = $file | str replace -r '(\.nu)?$' '_setx.nu'

    open $file
    | str trim --char (char nl)
    | split row -r $regex
    | each {|block|
        $block
        | escape-escapes
        | ('print ("> ' + $in + '" | nu-highlight)' + (char nl) + $block
            + "\nprint $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);\n\n")
    }
    | prepend 'mut $prev_ts = date now'
    | str join (char nl)
    | if $echo {
        return $in
    } else {
        save -f $out_file

        print $'the file ($out_file) is produced. Source it'
        commandline edit -r $'source ($out_file)'
    }
}

# Check .nu module files to determine which commands depend on other commands.
#
# > dependencies tests/assets/example-mod1.nu tests/assets/example-mod2.nu
# | first 3
# ╭─#─┬──caller───┬─────callee─────┬─filename_of_caller─┬─step─╮
# │ 0 │ command-3 │ lscustom       │ example-mod1.nu    │    0 │
# │ 1 │ command-3 │ sort-by-custom │ example-mod1.nu    │    0 │
# │ 2 │ command-5 │ command-3      │ example-mod1.nu    │    0 │
# ╰───┴───────────┴────────────────┴────────────────────┴──────╯
export def dependencies [
    ...paths: path # paths to a .nu module files
    --keep_builtins # keep builtin commands in the result page
    --definitions_only # output only commands' names definitions
] {
    let $callees_to_merge = $paths
        | each {
            extract-module-commands $in --keep_builtins=$keep_builtins --definitions_only=$definitions_only
        }
        | flatten

    if $definitions_only {return $callees_to_merge}

    $callees_to_merge
    | insert step 0
    | generate {|i|
        if ($i | is-not-empty) {
            {out: $i, next: ($i | join-next $callees_to_merge)}
        }
    } $in
    | flatten
    | uniq-by caller callee
}

# Parse commands definitions with their docstrings, output a table.
export def parse-docstrings [
    file?
] {
    if $file == null {
        collect
    } else {
        $file | open | collect
    }
    | parse -r '(?:\n\n|^)(?<definit_line>(?:(?:#.*\n)*)?(?:export def.*))'
    | get definit_line
    | each {
        let $lines = lines

        let $command_name = $lines
            | last
            | extract-command-name

        let $blocks = $lines
            | if ($lines | length) > 1 {
                drop
                | str replace --all --regex '^#( ?)|( +$)' ''
                | split list ''
                | each {str join (char nl) | $"($in)\n"}
            } else {['']}

        let $command_description = $blocks.0
            | if $in =~ '(^|\n)>' {''} else {
                str trim --char (char nl)
            }

        let $examples = $blocks
            | if $command_description == '' {} else {
                skip
            }
            | each {parse-example}
            | flatten

        { command_name: $command_name
            command_description: $command_description
            examples: $examples
            input: ($lines | drop | str join (char nl)) }
    }
}

# Execute examples in the docstrings of the module commands and update the results accordingly.
export def update-docstring-examples [
    module_file: path
    --command_filter: string = '' # filter commands by their name to update examples at
    --use_statement: string = '' # use statement to execute examples with (like 'use module.nu'). Can be omitted to try to deduce automatically
    --echo # output script to stdout instead of updating the module_file provided
    --no_git_check # don't check for the emptiness of the working tree
] {
    let pwd = pwd

    cd ($module_file | path dirname)

    if not $no_git_check {
        git status --short
        | if not ($in | lines | parse '{s} {m} {f}' | is-empty) {
            error make {msg: $"Working tree isn't empty. Please commit or stash all changed files.\n($in)"}
        }
    }

    let $raw_module = open $module_file

    cd $pwd

    $raw_module
    | parse-docstrings
    | if $command_filter == '' {} else {
        where command_name =~ $command_filter
    }
    | execute-update-example-results --module_file $module_file --use_statement $use_statement
    | prepare-substitutions
    | reject command_description command_name examples -i
    | reduce -f $raw_module {|i acc|
        $acc | str replace -a $i.input $i.updated
    }
    | str replace -r '\n*$' "\n" # add ending new line
    | if $echo {} else {
        save $module_file --force
    }
}

# Generate nupm tests from examples in docstrings
export def generate-nupm-tests [
    $module_file
    --echo
] {
    let tests_script = parse-docstrings $module_file
        | select command_name examples
        | where examples != []
        | each {|i|
            $i.examples
            | enumerate
            | each {|e| generate-test-command $i.command_name $e.index $e.item.command}
        }
        | flatten
        | prepend (
            $module_file
            | path expand
            | path relative-to (pwd)
            | [.. $in]
            | path join
            | $'use ($in) *'
        )
        | str join "\n\n"
        | str replace -r "\n*$" "\n"

    if $echo {return $tests_script}

    # I assume that we are in root directory here
    let $tests_filename = $'dotnu-examples-test-($module_file | path basename)'
    let $tests_path = ['tests' $tests_filename] | path join
    let $tests_mod_path = ['tests' mod.nu] | path join
    let $export_statement = $"export use ($tests_filename) *\n"

    mkdir tests
    $tests_script | save -f $tests_path

    if ($tests_mod_path | path exists) {
        open $tests_mod_path
        | if ($in | str contains $tests_filename) {
            return
        } else {
            $"($in)\n($export_statement)"
        }
    } else {
        $export_statement
    }
    | save -f $tests_mod_path
}

# Generate `.numd` from `.nu` divided on blocks by "\n\n"
export def generate-numd [] {
    split row -r "\n+\n"
    | each {$"```nu\n($in)\n```\n"}
    | str join (char nl)
}

# extract a code of a command from a module and save it as a `.nu' file, that can be sourced
# by executing this `.nu` file you'll have all variables in your environment for debuging or development
export def extract-command [
    $file: path # a file of a module to extract a command from
    $command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save extracted command script
    --clear_vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
    --set_vars: record # set variables for a command
    --code_editor = 'code' # code is my editor of choice to open the result file
] {
    let $dotnu_vars_delim = '#dotnu-vars-end'

    let $extracted_command = dummy-command $command $file $dotnu_vars_delim
        | nu -n -c $in
        | split row $dotnu_vars_delim

    if $extracted_command.1? == null {
        error make --unspanned {msg: $'no command `($command)` was found'}
    }

    let $filename = $output | default $'($command).nu'

    $extracted_command.0
    | variable-definitions-to-record
    | if ($filename | path exists) and not $clear_vars {
        merge ( # here we use defined variables from the previously extracted command to a file
            open $filename
            | split row $dotnu_vars_delim
            | get 0
            | variable-definitions-to-record
        )
    } else {}
    | if $set_vars != null {
        merge $set_vars
    } else {}
    | items {|k v| $'let $($k) = ($v)'}
    | append (char nl)
    | str join (char nl)
    | $in + $dotnu_vars_delim + $extracted_command.1 + (char nl)
    | if $echo {
        return $in
    } else {
        save -f $filename

        commandline edit --replace $"^($code_editor) ($filename); commandline edit --replace 'source ($filename)'"
    }
}

# open a `.nu` file with blocks of tests divided by double new lines, execute each, report problems
export def test [
    file: path # path to `.nu` file
] {
    let $blocks = open $file
        | split row -r "\n+\n"

    $blocks
    | skip
    | length
    | $"Number of tests to execute ($in)"
    | print

    # the first block is to be repeated in every other block execution
    let $common = $blocks.0

    $blocks
    | skip
    | par-each {|i|
        nu --no-config-file -c $"($common)\n($i)"
        | complete
        | if $in.exit_code != 0 {
            insert command $i
        }
    }
}
