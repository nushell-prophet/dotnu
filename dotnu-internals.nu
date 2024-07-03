# make a record from code with variable definitions
#
# > "let $quiet = false; let $no_timestamp = false" | variables_definitions_to_record | to nuon
# {quiet: false, no_timestamp: false}
#
# > "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variables_definitions_to_record | to nuon
# {a: b, c: d}
export def variables_definitions_to_record []: string -> record {
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
    } else {}
    | $"$env.config.table = ($env.config.table | to nuon); ($in); ($example_command)"
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

export def execute-examples [
    module_file: path
    --use_statement: string = '' # use statement to execute examples with (like 'use module.nu'). Can be omitted to try to deduce automatically
] {
    par-each {|row|
        $row
        | insert examples_res {
            get examples_parsed
            | each {|e|
                gen-example-exec-command $e.command $row.command_name $use_statement $module_file
                | nu --no-newline -c $in
                | complete
                | if $in.exit_code == 0 {get stdout} else {get stderr}
                | ansi strip
                | $e.annotation + "\n" + "> " + $e.command + "\n" + $in
            }
            | str trim -c "\n"
            | str join "\n\n"
            | lines
            | each {|i| '# ' + $i}
            | str trim
            | str join "\n"
        }
    }
}

# helper function for use inside of generate
#
# > [[parent child step]; [a b 0] [b c 0]] | join-next $in | to nuon
# [[parent, child, step]; [a, c, 1]]
export def 'join-next' [
    children_to_merge
] {
    join -l $children_to_merge child parent
    | select parent child_ step
    | rename parent child
    | upsert step {|i| $i.step + 1}
    | where child != null
}
