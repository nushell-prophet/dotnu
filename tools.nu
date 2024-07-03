use dotnu.nu *
use dotnu-internals.nu *

def main [] {}

def 'main testing' [] {
    {
        [tests-related numd-internals.nu]
        | path join
        | open
        | collect
        | parse-docstrings
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'numd-internals-parse-docstrings1.yaml']
        | path join
    )
}


def do_closure_save_results [
    output_file: path
] {
    let closure = $in

    view source $closure
    | lines | skip | drop | str trim
    | each {$'# ($in)'}
    | str join (char nl)
    | $in + (char nl) + (do $closure) + (char nl)
    | save -fr $output_file
}
