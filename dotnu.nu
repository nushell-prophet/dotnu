use dotnu-internals.nu [
    variables_definitions_to_record
    parse-example
    escape-escapes
    extract-command-name
    execute-update-example-results
    extract-module-commands
    prepare-substitutions
    nu-completion-command-name
    join-next
]

# create a file that will print and execute all the commands by blocks.
# Blocks are separated by empty lines between commands.
export def set-x [
    file: path # path to `.nu` file
    --echo # output script to terminal
] {
    let $out_file = $file + 'setx.nu'

    open $file
    | str trim --char (char nl)
    | split row -r "\n+\n"
    | each {|block|
        $block
        | escape-escapes
        | nu-highlight
        | ($'print "> ($in)"(char nl)($block)'
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

    # the closure below is used as a highlighted in an editor constructor
    # for the command that will be executed in `nu -c`
    let $dummy_closure = {|function|
        let $params = scope commands
            | where name == $command
            | get signatures.0
            | values
            | get 0
            | each {
                if ($in.parameter_type == 'rest') {
                    if ($in.parameter_name == '') {
                        upsert parameter_name 'rest'  # if rest parameters named $rest, in the signatures it doesn't have a name
                    } else {}
                    | default [] parameter_default
                } else {}
            }
            | where parameter_name != null
            | each {|i|
                let $param = $i.parameter_name | str replace -a '-' '_' | str replace '$' ''

                let $value = $i.parameter_default?
                    | if $in == null {} else {
                        if $i.syntax_shape in ['string' 'path'] {
                            $"'($in)'"
                        } else {}
                    }
                    | default (
                        if $i.parameter_type == 'switch' { false }
                            else if $i.is_optional { 'null' }
                            else { $i.syntax_shape }
                    )
                    | if $in == '' {"''"} else {}
                    | into string

                $"let $($param) = ($value)"
            }
            | str join "\n"

        let $main = view source $command
            | lines
            | upsert 0 {|i| '# ' + $i}
            | drop
            | append '# }'
            | prepend $dotnu_vars_delim
            | str join "\n"

        "source '$file'\n\n" + $params + "\n\n" + $main
    }

    let $extracted_command = view source $dummy_closure
        | lines | skip | drop | str join "\n"
        | str replace -a '$command' $command
        | str replace -a '$file' $file
        | str replace -a '$dotnu_vars_delim' $"'($dotnu_vars_delim)'"
        | $"source ($file)\n\n($in)"
        | nu -n -c $in
        | split row $dotnu_vars_delim

    let $filename = $output | default $'($command).nu'

    $extracted_command.0
    | variables_definitions_to_record
    | if ($filename | path exists) and not $clear_vars {
        merge (
            open $filename
            | split row $dotnu_vars_delim
            | get 0
            | variables_definitions_to_record
        )
    } else {}
    | if $set_vars != null {
        merge $set_vars
    } else {}
    | items {|k v| $'let $($k) = ($v)'}
    | append (char nl)
    | str join (char nl)
    | $in + $dotnu_vars_delim + $extracted_command.1
    | if $echo {
        return $in
    } else {
        save -f $filename

        commandline edit --replace $"^($code_editor) ($filename); commandline edit --replace 'source ($filename)'"
    }
}

# Check .nu module files to determine which commands depend on other commands
export def dependencies [
    ...paths: path # paths to a .nu module files
    --keep_builtins # keep builtin commands in the result page
    --definitions_only # output only commands' names definitions
] {
    let $children_to_merge = $paths
        | each {
            extract-module-commands $in --keep_builtins=$keep_builtins --definitions_only=$definitions_only
        }
        | flatten

    if $definitions_only {return $children_to_merge.command_name}

    $children_to_merge
    | insert step 0
    | generate $in {|i|
        if ($i | is-not-empty) {
            {out: $i, next: ($i | join-next $children_to_merge)}
        }
    }
    | flatten
    | uniq-by parent child
    | sort-by parent step child
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

# parse commands definitions with docstrings
export def parse-docstrings [
    file?
] {
    if $file == null {
        collect
    } else {
        $file | open | collect
    }
    | parse -r '(?:\n\n|^)((?:(?:#.*\n)*)?(?:export def.*))'
    | get capture0
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

# Execute examples in the docstrings of module commands and update results accordingly
export def update-docstring-examples [
    module_file: path
    --command_filter: string = '' # filter commands by their name to update examples at
    --use_statement: string = '' # use statement to execute examples with (like 'use module.nu'). Can be omitted to try to deduce automatically
    --echo # output script to stdout instead of saving ot the file
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

export def generate-numd [] {
    split row -r "\n+\n"
    | each {$"```nu\n($in)\n```\n"}
    | str join (char nl)
}
