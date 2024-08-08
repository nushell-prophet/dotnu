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
        ['tests-related' 'output-yaml' 'parse-docstrings1-numd-internals.yaml']
        | path join
    )
}

def 'test-dependencies' [] {
    {
        dependencies tests-related/example-mod1.nu tests-related/example-mod2.nu
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'output-yaml' 'dependencies.yaml']
        | path join
    )
}

def 'test-dependencies-keep_builtins' [] {
    {
        dependencies tests-related/example-mod1.nu tests-related/example-mod2.nu --keep_builtins
        | to yaml
    }
    | do_closure_save_results (
        ['tests-related' 'output-yaml' 'dependencies --keep_bulitins.yaml']
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

def 'main release' [] {
    let $git_info = (gh repo view --json description,name | from json);
    let $git_tag = (git tag | lines | prepend '0.0.0' | sort -n | last | inc -p)
    let $desc = ($git_info | get description)

    open nupm.nuon
    | update description ($desc | str replace -r $'^($git_info.name) - ' '')
    | update version $git_tag
    | save -f nupm.nuon

    'README.md'
    | if ($in | path exists) {
        open -r
    } else {"\n"}
    | lines
    | update 0 ('<h1 align="center">' + $git_info.name + '<br>' + $desc + '</h1>')
    | str join (char nl)
    | $in + (char nl)
    | save -f README.md

    prettier README.md -w

    git add nupm.nuon
    git commit -m $'($git_tag) nupm version'
    git tag $git_tag
}
