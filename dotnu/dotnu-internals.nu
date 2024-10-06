use std iter scan

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
export def variable-definitions-to-record []: string -> record {
    str replace -a ';' ";\n"
    | $"($in)(char nl)(
        $in
        | parse -r 'let (?:\$)*(?<var>.*) ='
        | get var
        | uniq
        | each {$'($in): $($in)'}
        | str join ' '
        | $'{($in)} | to nuon' # this way we ensure the proper formatting for bool, numeric and string vars
    )"
    | nu -n -c $in
    | from nuon
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
    | str trim --char (char nl) annotation command result
}

# > 'export def --env "test" --wrapped' | lines | last | extract-command-name
# test
export def 'extract-command-name' [
    $module_file? # path to a nushell module file
] {
    str replace -r '\[.*' ''
    | str replace -r '^(export )?def ' ''
    | str replace -ra '(--(env|wrapped) ?)' ''
    | str replace -ra "\"|'|`" ''
    | str trim
    | if $module_file == null {} else {
        str replace -r '^main( |$)' (
            $module_file
            | path expand
            | path split
            | where $it != mod.nu
            | last
            | str replace -r '\.nu$' ' '
        )
        | str trim
    }
}

# generate command to execute `>` example command in a new nushell instance
# in case of any problems - use `--use_statement` flag
export def gen-example-exec-command [
    example_command
    command_name
    use_statement
    module_file
] {
    let $module_stem = $module_file | path parse | get stem

    # the logic to deduce the use statement is very fragile and are better to be remade
    if $use_statement != '' {
        $use_statement
    } else if ($example_command | str contains $'($module_stem) ($command_name)') {
        $'use "($module_file)"'
    } else if $module_stem == 'mod' {
        $'use "($module_file | path dirname)" *'
    } else {
        $'use "($module_file)" *'
    }
    | $"($in);\n($example_command)"
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
    $context | str replace -r '^.*? extract-command-code ' '' | str trim | split row ' ' | first
    | path expand | open $in -r | lines
    | where $it =~ '^(export )?def '
    | each {
        extract-command-name
    }
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
# > extract-module-commands --definitions_only tests/assets/b/example-mod1.nu | first 3
# ╭───┬──────────────┬────────────────────╮
# │ # │    caller    │ filename_of_caller │
# ├───┼──────────────┼────────────────────┤
# │ 0 │ example-mod1 │ example-mod1.nu    │
# │ 1 │ lscustom     │ example-mod1.nu    │
# │ 2 │ command-5    │ example-mod1.nu    │
# ╰───┴──────────────┴────────────────────╯
export def extract-module-commands [
    path: path # path to a .nu module file.
    --keep_builtins # keep builtin commands in the result page
    --definitions_only # output only commands' names definitions
] {
    let $raw_script = open $path -r

    let $defined_commands = $raw_script
        | lines
        | where $it =~ '^(export )?def.*\['
        | wrap line
        | insert caller {|i|
            $i.line
            | extract-command-name $path
        }
        | insert filename_of_caller ($path | path basename)

    if $definitions_only or ($defined_commands | is-empty) {return ($defined_commands | select caller filename_of_caller)}

    let $with_index = $defined_commands
        | insert start {|i| $raw_script | str index-of $i.line}

    let $dependencies = nu --ide-ast $path
        | from json
        | flatten span
        | join $with_index start -l
        | merge (
            $in
            | select caller filename_of_caller
            | scan {} --noinit {|prev curr| if $curr.caller? == null {$prev} else {$curr}}
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
        | where caller not-in ($dependencies.caller | uniq)
        | insert callee null

    $dependencies | append $commands_with_no_deps
}

# update examples column with results of execution commands
export def execute-update-example-result [
    --module_file: string = ''
    --use_statement: string = ''
] {
    update examples {|row|
        $row.examples
        | upsert result {|i|
            let $example_command = $i.command
                | str replace -arm '^> ' ''
                | gen-example-exec-command $in $row.command_name $use_statement $module_file

            nu --no-newline --commands $example_command
            | complete
            | if $in.exit_code == 0 {get stdout} else {
                print $"the next command has failed:\n`($example_command)`\n\n($in.stderr)"
                'example update failed'
            }
            | ansi strip
            | str trim --char (char nl)
        }
    }
}

# prepare pairs of substituions of old results and new results
export def prepare-substitutions [] {
    insert updated {|e|
        $e.examples
        | each {|i|
            [$i.annotation $i.command $i.result]
            | compact --empty
            | str join (char nl)
        }
        | [$e.command_description $in]
        | flatten
        | compact --empty
        | str join $"(char nl)(char nl)"
        | lines
        | each {$"# ($in)" | str trim}
        | str join (char nl)
    }
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
    # the closure below is used as a highlighted in an editor constructor
    # for the command that will be executed in `nu -c`
    let $dummy_closure = {|function|
        let $params = scope commands
            | where name == $command
            | get -i signatures.0
            | if $in == null {
                error make --unspanned {msg: 'no command $command was found'}
            } else {}
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
                    | if $in == null {
                        if $i.parameter_type == 'switch' { false } else {}
                    } else {}
                    | if $in == '' {"''"} else {}
                    | default "'null'"
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

    view source $dummy_closure
    | lines | skip | drop | str join "\n"
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
        $'export def `($command_name)-($index)-test` [] {'
            ($command | str replace -arm `^(> )?` `    `)
        '}'
    ] | str join (char nl)
}
