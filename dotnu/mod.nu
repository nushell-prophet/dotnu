use dotnu-internals.nu [
    dummy-command
    escape-for-quotes
    execute-update-example-result
    extract-command-name
    extract-module-commands
    generate-test-command
    join-next
    nu-completion-command-name
    parse-example
    prepare-substitutions
    variable-definitions-to-record
]

use ('..' | path join tests nupm utils dirs.nu) find-root

# Check .nu module files to determine which commands depend on other commands.
#
# > dependencies ...(glob tests/assets/module-say/say/*.nu)
# ╭─#─┬──caller──┬─filename_of_caller─┬──callee──┬─step─╮
# │ 0 │ hello    │ hello.nu           │          │    0 │
# │ 1 │ question │ ask.nu             │          │    0 │
# │ 2 │ say      │ mod.nu             │ hello    │    0 │
# │ 3 │ say      │ mod.nu             │ hi       │    0 │
# │ 4 │ say      │ mod.nu             │ question │    0 │
# │ 5 │ hi       │ mod.nu             │          │    0 │
# │ 6 │ test-hi  │ test-hi.nu         │ hi       │    0 │
# ╰───┴──────────┴────────────────────┴──────────┴──────╯
export def dependencies [
    ...paths: path # paths to nushell module files
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

# Filter commands after `dotnu dependencies` that aren't used by any other command containing `test` in its name.
#
# > dependencies ...(glob tests/assets/module-say/say/*.nu) | filter-commands-with-no-tests
# ╭─#─┬──caller──┬─filename_of_caller─╮
# │ 0 │ hello    │ hello.nu           │
# │ 1 │ question │ ask.nu             │
# │ 2 │ say      │ mod.nu             │
# ╰───┴──────────┴────────────────────╯
export def filter-commands-with-no-tests [] {
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
export def parse-docstrings [
    module_file? # path to a nushell module file
] {
    if $module_file == null {
        collect
    } else {
        $module_file | open | collect
    }
    | parse -r '(?:\n\n|^)(?<definit_line>(?:(?:#.*\n)*)?(?:export def.*))'
    | get definit_line
    | each {
        let $lines = lines

        let $command_name = $lines
            | last
            | extract-command-name $module_file

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
    module_file: path # path to a nushell module file
    --command_filter: string = '' # filter commands by their name to update examples at
    --use_statement: string = '' # use statement to execute examples with (like 'use module.nu'). Can be omitted to try to deduce automatically
    --echo # output script to stdout instead of updating the module_file provided
    --no_git_check # don't check for the emptiness of the working tree
] {
    let pwd = pwd

    cd ($module_file | path dirname)

    if not $no_git_check {
        let git_status = git status --short

        $git_status
        | lines
        | parse '{s} {m} {f}'
        | where f =~ $'($module_file | path basename)$'
        | is-not-empty
        | if $in {
            error make --unspanned {
                msg: ("Working tree isn't empty. Please commit or stash changed files, " +
                        "or use `--no_git_check` flag. Uncommited files:\n" + $git_status)
            }
        }
    }

    let $raw_module = open $module_file

    cd $pwd

    $raw_module
    | parse-docstrings
    | if $command_filter == '' {} else {
        where command_name =~ $command_filter
    }
    | execute-update-example-result --module_file $module_file --use_statement $use_statement
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
        | escape-for-quotes
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

# Generate nupm tests from examples in docstrings
export def generate-nupm-tests [
    $module_file: path # path to a nushell module file
    --echo # output script to stdout instead of updating the module_file provided
] {
    let $module_file = $module_file | path expand
    let $root = find-root ($module_file | if ($in | path type) == file {path dirname} else {})

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
            | path relative-to $root
            | [.. $in]
            | path join
            | $'use ($in) *'
        )
        | str join "\n\n"
        | str replace -r "\n*$" "\n"

    if $echo {return $tests_script}

    let $tests_filename = $'dotnu-examples-test-($module_file | path basename)'
    let $tests_path = [$root 'tests' $tests_filename] | path join
    let $tests_path_abs = $tests_path | path expand
    let $tests_mod_path = $tests_path | str replace $tests_filename 'mod.nu'
    let $export_statement = $"export use ($tests_filename) *\n"

    mkdir ($root | path join 'tests')
    $tests_script | save -f $tests_path_abs

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
export def extract-command-code [
    $module_file: path # path to a nushell module file
    $command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save extracted command script
    --clear_vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
    --set_vars: record # set variables for a command
    --code_editor = 'code' # code is my editor of choice to open the result file
] {
    let $command = $command
        | if $in =~ '\s' and $in !~ "^(\"|')" {
            $'"($in)"'
        } else {}
    let $dotnu_vars_delim = '#dotnu-vars-end'

    let $extracted_command = dummy-command $command $module_file $dotnu_vars_delim
        | nu -n -c $in
        | split row $dotnu_vars_delim

    if $extracted_command.1? == null {
        error make --unspanned {msg: $'no command `($command)` was found'}
    }

    let $filename = $output
        | default $'($command | str trim -c '"' | str trim -c "'").nu'

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
    | items {|k v| $'let $($k) = ($v | to nuon)' }
    | append (char nl)
    | str join (char nl)
    | $in + $dotnu_vars_delim + $extracted_command.1 + (char nl)
    | if $echo {
        return $in
    } else {
        save -f $filename

        commandline edit --replace $" ^($code_editor) \"($filename)\"; commandline edit --replace ' source \"($filename)\"'"
    }
}

export def 'list-main-commands' [
    $path: path
] {
    open $path -r
    | lines
    | where $it =~ '^(export )?def '
    | extract-command-name
    | where $it starts-with 'main'
    | str replace 'main ' ''
    | input list "Choose a command:"
    | if ($in | is-empty) {
        print 'No command found'
        return
    } else {}
    | if $in == 'main' { '' } else {}
    | commandline edit -r $"nu ($path) ($in)"
}