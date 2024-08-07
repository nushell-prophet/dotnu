use std iter scan

# make a record from code with variable definitions
#
# > "let $quiet = false; let $no_timestamp = false" | variable-definitions-to-record | to nuon
# {quiet: false, no_timestamp: false}
#
# > "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record | to nuon
# {a: b, c: d}
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
export def 'extract-command-name' [] {
    str replace -r '\[.*' ''
    | str replace -r '^(export )?def ' ''
    | str replace -ra '(--(env|wrapped) ?)' ''
    | str replace -ra "\"|'|`" ''
    | str trim
}

# generate command to execute `>` example command in a new nushell instance
export def gen-example-exec-command [
    example_command
    command_name
    use_statement
    module_file
] {
    if $use_statement != '' {
        $use_statement
    } else if ($example_command | str contains $'($module_file | path parse | get stem) ($command_name)') {
        $'use "($module_file)"'
    } else {
        # I use asterisk for importing all the commands because the example might contain other commands from the module
        $'use "($module_file)"; use "($module_file)" *'
    }
    | $"$env.config.table = ($env.config.table | to nuon);\n($in);\n($example_command)"
}

# Escapes symbols to be printed unchanged inside a `print "something"` statement.
#
# > 'abcd"dfdaf" "' | escape-escapes
# abcd\"dfdaf\" \"
export def escape-escapes []: string -> string {
    str replace --all --regex '(\\|\")' '\$1'
}

# context aware completions for defined command names in nushell module files
#
# > nu-completion-command-name 'dotnu extract-command tests/assets/example-mod1.nu' | first 3
# ╭───┬────────────────╮
# │ 0 │ main           │
# │ 1 │ lscustom       │
# │ 2 │ sort-by-custom │
# ╰───┴────────────────╯
export def nu-completion-command-name [
    context: string
] {
    $context | str replace -r '^.*? extract-command ' '' | str trim | split row ' ' | first
    | path expand | open $in -r | lines
    | where $it =~ '^(export )?def '
    | each {
        extract-command-name
    }
}

# Extract table with information on which commands use which commands
#
# > extract-module-commands tests/assets/example-mod1.nu | first 3
# ╭─#─┬──caller───┬─────callee─────┬─filename_of_caller─╮
# │ 0 │ command-3 │ lscustom       │ example-mod1.nu    │
# │ 1 │ command-3 │ sort-by-custom │ example-mod1.nu    │
# │ 2 │ command-5 │ command-3      │ example-mod1.nu    │
# ╰───┴───────────┴────────────────┴────────────────────╯
#
# > extract-module-commands --definitions_only tests/assets/example-mod1.nu | first 3
# ╭─#─┬─────caller─────┬─filename_of_caller─╮
# │ 0 │ main           │ example-mod1.nu    │
# │ 1 │ lscustom       │ example-mod1.nu    │
# │ 2 │ sort-by-custom │ example-mod1.nu    │
# ╰───┴────────────────┴────────────────────╯
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
            $i.line | extract-command-name
        }
        | insert filename_of_caller ($path | path basename)

    if $definitions_only {return ($defined_commands | select caller filename_of_caller)}

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
        | where shape == 'shape_internalcall'
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
export def execute-update-example-results [
    --module_file: string = ''
    --use_statement: string = ''
] {
    update examples {|row|
        $row.examples
        | upsert result {|i|
            $i.command
            | str replace -arm '^> ' ''
            | gen-example-exec-command $in $row.command_name $use_statement $module_file
            | nu --no-newline --commands $in
            | complete
            | if $in.exit_code == 0 {get stdout} else {get stderr}
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
                error make --unspanned {msg: $'no command `($command)` was found'}
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
    (
        $'export def `test-($command_name)-($index)` [] {' + (char nl) +
        ($command | str replace -arm `^(> )?` `    `) + (char nl) +
        '}'
    )
}
