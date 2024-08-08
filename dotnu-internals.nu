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
export def extract-module-commands [
    path: path # path to a .nu module file.
    --keep_builtins # keep builtin commands in the result page
    --definitions_only # output only commands' names definitions
] {
    let $raw_script = open $path -r
    let $path_basename = $path | path basename

    let $table = $raw_script
        | lines
        | enumerate
        | rename row_number line
        | where line =~ '^(export )?def.*\['
        | insert command_name {|i|
            $i.line | extract-command-name
        }
        | insert filename_of_caller $path_basename

    if $definitions_only {return ($table | select command_name filename_of_caller)}

    let $with_index = $table
        | insert start {|i| $raw_script | str index-of $i.line}

    let $res1 = nu --ide-ast $path
        | from json
        | flatten span
        | join $with_index start -l
        | merge (
            $in
            | select command_name filename_of_caller
            | scan {command_name: null filename_of_caller: null} --noinit {|prev curr| if ($curr == {command_name: null filename_of_caller: null}) {$prev} else {$curr}}
        )
        | where shape == 'shape_internalcall'
        | if $keep_builtins {} else {
            where content not-in (
                help commands | where command_type in ['built-in' 'keyword'] | get name
            )
        }
        | select command_name content filename_of_caller
        | rename caller callee
        | where caller != null

    $res1
    | append ($table | select command_name | rename caller
        | where caller not-in ($res1.caller | uniq)
        | insert callee null
        | insert filename_of_caller $path_basename)
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
# > [[caller callee step]; [a b 0] [b c 0]] | join-next $in | to nuon
# [[caller, callee, step]; [a, c, 1]]
export def 'join-next' [
    callees_to_merge
] {
    join -l $callees_to_merge callee caller
    | select caller callee_ step filename_of_caller
    | rename caller callee
    | upsert step {|i| $i.step + 1}
    | where callee != null
}
