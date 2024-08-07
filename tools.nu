use dotnu.nu *
use dotnu-internals.nu *

def main [] {}

def 'main testing' [] {
    test-parse-docstrings
    test-dependencies
    test-dependencies-keep_builtins
}

def 'test-parse-docstrings' [] {
    {
        [tests-related numd-internals.nu]
        | path join
        | open
        | parse-docstrings
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'numd-internals-parse-docstrings1.yaml']
        | path join
    )
}

def 'test-dependencies' [] {
    {
        dependencies tests-related/example-module-for-tests.nu tests-related/example-module-for-tests2.nu
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'dependencies.yaml']
        | path join
    )
}

def 'test-dependencies-keep_builtins' [] {
    {
        dependencies tests-related/example-module-for-tests.nu tests-related/example-module-for-tests2.nu --keep_builtins
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'dependencies --keep_bulitins.yaml']
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

    print $'file created ($output_file)'
}
