# extract a command from a module and save it as a file, that can be sourced
export def main [
    $file: path # a file of a module to extract a command from
    $function: string@nu-completion-command-name # the name of the command to extract
    --output: path # a file path to save extracted command script
] {
    let dummy_closure = {|function| # closure is used as the constructor for the command for `nu -c` highlighted in an editor
        let $flags = (
            scope commands
            | where name == $function
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
            | each {|i| $"let $($i.parameter_name) = (
                $i.parameter_default?
                | default (
                    if $i.parameter_type == 'switch' { false }
                        else if $i.is_optional { null }
                        else { $i.syntax_shape }
                )
                | if $in == '' {"''"} else {}
                | into string
            )"}
            | str join "\n"
        )

        let $main = (view source $function | lines | upsert 0 {|i| '# ' + $i} | drop | str join "\n")

        "source '$file'\n\n" + $flags + "\n\n" + $main
    }

    let $command_to_extract_the_command = ($"source ($file)\n\n" +
        (
            view source $dummy_closure
            | lines | skip | drop | str join "\n"
            | str replace -a '$function' $function | str replace -a '$file' $file
        )
    )

    let $extracted_command = (nu -n -c $command_to_extract_the_command)

    let $filename = $output | default $'($function)(date now | format date "%s").nu'

    $extracted_command | save -f $filename

    commandline $"code ($filename); commandline 'source ($filename)'"
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
