# extract a command from a module and save it as a file, that can be sourced
export def main [
    $file: path
    $function: string@command-name
    --output: path
] {
    let $out = (
        nu -n -c $"source ($file);
        let $flags = \(scope commands | where name == ($function) | get signatures.0 | values | get 0 | where parameter_name != null | each {|i| $'let $\($i.parameter_name\) = ' + \($i.parameter_default? | default \(if $i.parameter_type == 'switch' {false} else {$"'\($i.syntax_shape\)'"}\) | into string\)} | str join '\n'\);
        let $main = \(view source ($function) | lines | upsert 0 {|i| '# ' + $i} | drop | str join '\n'\);
        'source ($file)\n\n' + $flags + '\n\n' + $main"
    )

    let $filename = $output | default $'($function)(date now | format date "%s").nu'

    $out | save -f $filename

    commandline $'source ($filename)'
}

def command-name [
    context: string
] {
    $context | str trim | split row ' ' | last | path expand | open $in -r | lines | where $it =~ '\sdef ' | each { str replace -r ' \[.*' '' | split row ' ' | last | str trim -c "'"}
}
