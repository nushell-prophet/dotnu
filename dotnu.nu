use std iter scan

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
        ($"print `> ($block | str replace -ar '([^\\]?)"' '$1\"' | nu-highlight)`\n($block)"
        + "\nprint $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);\n\n")
    }
    | prepend 'mut $prev_ts = date now'
    | if $echo {
        str join (char nl)
        | return $in
    } else {
        save -f $out_file
    }

    print $'the file ($out_file) is produced. Source it'

    commandline $'source ($out_file)'
}

# extract a command from a module and save it as a file, that can be sourced
export def extract [
    $file: path # a file of a module to extract a command from
    $command: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save extracted command script
    --clear_vars # clear variables previously set in the extracted .nu file
    --echo # output the command to the terminal
] {
    let $dotnu_vars_string = '#dotnu-vars-end'

    let $dummy_closure = {|function| # closure is used as the constructor for the command for `nu -c` highlighted in an editor
        let $params = scope commands
            | where name == $command
            | get signatures.0
            | values
            | get 0
            | each {
                if ($in.parameter_type == 'rest') {
                    if ($in.parameter_name == '') {
                        upsert parameter_name 'rest'  # if rest paramters named $rest, in the signatures it doesn't have a name
                    } else {}
                    | default [] parameter_default
                } else {}
            }
            | where parameter_name != null
            | each {|i| $"let $($i.parameter_name | str replace -a '-' '_' | str replace '$' '') = (
                $i.parameter_default?
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
            )"}
            | str join "\n"

        let $main = view source $command
            | lines
            | upsert 0 {|i| '# ' + $i}
            | drop
            | append '# }'
            | prepend $dotnu_vars_string
            | str join "\n"

        "source '$file'\n\n" + $params + "\n\n" + $main
    }

    let $command_to_extract_the_command = view source $dummy_closure
        | lines | skip | drop | str join "\n"
        | str replace -a '$command' $command
        | str replace -a '$file' $file
        | str replace -a '$dotnu_vars_string' $"'($dotnu_vars_string)'"
        | $"source ($file)\n\n($in)"

    let $extracted_command = nu -n -c $command_to_extract_the_command
        if $echo {return $in} else {}

    let $filename = $output | default $'($command).nu'

    if ($filename | path exists) and not $clear_vars {
        open $filename
        | split row $dotnu_vars_string
        | get 0
        | $in + $dotnu_vars_string + (
            $extracted_command
            | split row $dotnu_vars_string
            | get 1
        )
    } else {$extracted_command}
    | save -f $filename

    # code is my editor of choice here
    commandline edit --replace $"code ($filename); commandline edit --replace 'source ($filename)'"
}

def nu-completion-command-name [
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

# Check .nu module file for which commands use other commands
export def dependencies [
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
            | str replace -r '^(export )?def( --(env|wrapped))* (?<command>.*?) \[.*' '$command'
            | str trim -c "\""
            | str trim -c "'"
            | str trim -c "`"
        }

    if $definitions_only {return ($table | get command_name)}

    let $with_index = $table | insert start {|i| $raw_script | str index-of $i.line}
    let $ast = nu --ide-ast $path | from json | flatten span
    let $join = $ast | join $with_index start -l
    let $scanned = $join | merge (
        $in.command_name
        | scan null {|prev curr| if ($curr == null) {$prev} else {$curr} }
        | wrap command_name
        | roll up
    )

    let $not_built_in_commands = $scanned
        | where shape in [shape_internalcall]
        | if $keep_builtins {} else {
            where content not-in (
                help commands | where command_type in ['builtin' 'keyword'] | get name
            )
        }

    let $childs_to_merge = $not_built_in_commands
        | select command_name content
        | rename parent child
        | where parent != null

    def 'join-next' [] {
        join -l $childs_to_merge child parent
        | select parent child_ step
        | rename parent child
        | upsert step {|i| $i.step + 1}
        | where child != null
    }

    generate ($childs_to_merge | insert step 0) {|i|
        if not ($i | is-empty) {{out: $i, next: ($i | join-next)}}
    }
    | flatten
    | uniq-by parent child
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

    # the first block is to be repeated in every other block exectuion
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
