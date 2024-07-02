# make a record from code with variable definitions
#
# > "let $quiet = false; let $no_timestamp = false" | variables_definitions_to_record
# ╭──────────────┬───────╮
# │ quiet        │ false │
# │ no_timestamp │ false │
# ╰──────────────┴───────╯
#
# > "let $a = 'a'\nlet $b = 'b'\n\n#comment" | variables_definitions_to_record
# ╭───┬─────╮
# │ a │ 'a' │
# │ b │ 'b' │
# ╰───┴─────╯
export def variables_definitions_to_record []: string -> record {
    str replace -a ";" "\n"
    | str replace -ar '#.*?(\n|$)' ''
    | parse -r 'let (?:\$)*(?<var>.*) = (?s)(?<val>.*?)(?=let|\n\n|$)'
    | compact --empty val # I'm not sure about this rule :\
    | update val {|i| $i.val | str replace -ar "(\n| )+" ' ' | str trim}
    | transpose --ignore-titles --as-record --header-row
}

export def parse-docstrings [] {
    parse -r "(?:\n\n|^)# (?<desc>.*)\n(?:#\n)(?<examples>(?:(?:\n#)|.)*)\nexport def(?: --(?:env|wrapped))* (?:'|\")?(?<command_name>.*?)(?:'|\")? \\["
}

export def parse-examples [] {
    str replace -ram '^# ?' ''
    | split row "\n\n" # By splitting on groups, we can execute in one command several lines that start with `>`
    | parse -r '(?<annotation>^.+\n)??> (?<command>.+(?:\n\|.+)*)'
}

export def gen-example-exec-command [
    example_command
    command_name
    use_statement
    module_file
] {
    if $use_statement != '' {
        $use_statement
    } else if ($example_command | str contains $'($module_file | path parse | get stem) ($command_name)') {
        $'use ($module_file)'
    } else if ($example_command | str contains $'($command_name)') {
        # I use asterisk for importing all the commands because the example might contain other commands from the module
        $'use ($module_file) *'
    } else {
        error make {
            msg: ($"Can't deduce use statement for example ($example_command). " +
                "Check if your example is correct or provide `--use_statement` param.")
        }
    }
    | $"($in); ($example_command)"
}

# Escapes symbols to be printed unchanged inside a `print "something"` statement.
#
# > 'abcd"dfdaf" "' | escape-escapes
# abcd\"dfdaf\" \"
export def escape-escapes []: string -> string {
    str replace --all --regex '(\\|\")' '\$1'
}

export def nu-completion-command-name [
    context: string
] {
    $context | str replace -r '^.*? extract ' '' | str trim | split row ' ' | first
    | path expand | open $in -r | lines
    | where $it =~ '(^|\s)def '
    | each {
        str replace -r ' \[.*' ''
        | split row ' '
        | last
        | str trim -c "'"
    }
}
