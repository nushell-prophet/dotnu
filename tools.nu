use dotnu.nu *
use dotnu-internals.nu *

def main [] {}

def 'main testing' [] {
    let nuon_file = ['tests-related' 'numd-internals-parse-docstrings1.yaml']
        | path join

    let test_parse_docstring = {
        [tests-related numd-internals.nu]
        | path join
        | open
        | collect
        | parse-docstrings
        | to yaml
    }

    view source $test_parse_docstring
    | lines | skip | drop | str trim
    | each {$'# ($in)'}
    | str join (char nl)
    | $in + (char nl) + (do $test_parse_docstring) + (char nl)
    | save -fr $nuon_file
}
