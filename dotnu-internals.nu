use std iter scan

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

# parse `>` examples from the parsed docstrings
export def parse-example [] {
    str replace -ram '^# ?' ''
    | split row "\n\n" # By splitting on groups, we can execute in one command several lines that start with `>`
    | parse -r '(?<annotation>^.+\n)??> (?<command>.+(?:\n\|.+)*)'
}

export def parse-example-2 [] {
    parse -r '(?<annotation>^(?:.+\n)+)??> (?<command>.+(?:\n(?:\||;).+)*)\n(?s)(?<result>.*)?'
}

# > 'export def --env "test" --wrapped' | lines | last | extract-command-name
# test
export def 'extract-command-name' [] {
    str replace -r '\[.*' ''
    | str replace 'export def ' ''
    | str replace -ra '(--(env|wrapped) ?)' ''
    | str replace -ra "\"|'" ''
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
    } else if ($example_command | str contains $'($command_name)') {
        # I use asterisk for importing all the commands because the example might contain other commands from the module
        $'use "($module_file)" *'
    } else {
        $'use "($module_file)"'
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
    $context | str replace -r '^.*? extract ' '' | str trim | split row ' ' | first
    | path expand | open $in -r | lines
    | where $it =~ '(^|\s)def '
    | each {
        str replace -r ' \[.*' ''
        | split row ' '
        | last
        | str trim -c "\""
        | str trim -c "'"
        | str trim -c "`"
    }
}

# Extract table with information on which commands use which commands
export def extract-module-commands [
    path: path # path to a .nu module file.
    --keep_builtins # keep builtin commands in the result page
    --definitions_only # output only commands' names definitions
] {
    let $raw_script = open $path -r

    let $table = $raw_script
        | lines
        | enumerate
        | rename row_number line
        | where line =~ '^(export )?def.*\['
        | insert command_name {|i|
            $i.line
            | str replace -ra '( --(?:env|wrapped))*' ''
            | str replace -r '^(export )?def (?<command>.*?) \[.*' '$command'
            | str trim -c "\""
            | str trim -c "'"
            | str trim -c "`"
        }

    if $definitions_only {return $table.command_name}

    let $with_index = $table
        | insert start {|i| $raw_script | str index-of $i.line}

    nu --ide-ast $path
    | from json
    | flatten span
    | join $with_index start -l
    | merge (
        $in.command_name
        | scan null --noinit {|prev curr| if ($curr == null) {$prev} else {$curr}}
        | wrap command_name
    )
    | where shape == 'shape_internalcall'
    | if $keep_builtins {} else {
        where content not-in (
            help commands | where command_type in ['built-in' 'keyword'] | get name
        )
    }
    | select command_name content
    | rename parent child
    | where parent != null
}

# insert example_res column with results of execution example commands
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
                | $e.annotation + "> " + $e.command + "\n" + $in
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
