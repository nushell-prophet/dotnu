const dotnupath = 'dotnu'
use $dotnupath *
use ($dotnupath | path join dotnu-internals.nu) *

def main [] {}

def 'main testing' [] {
    test-parse-docstrings
    test-dependencies
    test-dependencies-keep_builtins
}

def 'main test-nupm' [] {
    overlay use tests/nupm/test.nu --prefix as nupm
    nupm test
}

def 'test-parse-docstrings' [] {
    {
        [tests assets numd-internals.nu]
        | path join
        | open
        | parse-docstrings
        | to yaml
    }
    | do_closure_save_results 'parse-docstrings1-numd-internals.yaml'
}

def 'test-dependencies' [] {
    {
        [
            ([tests assets example-mod1.nu] | path join)
            ([tests assets example-mod2.nu] | path join)
        ]
        | dependencies ...$in
        | to yaml
    }
    | do_closure_save_results 'dependencies.yaml'
}

def 'test-dependencies-keep_builtins' [] {
    {
        [
            ([tests assets example-mod1.nu] | path join)
            ([tests assets example-mod2.nu] | path join)
        ]
        | dependencies ...$in --keep_builtins
        | to yaml
    }
    | do_closure_save_results 'dependencies --keep_bulitins.yaml'
}

def do_closure_save_results [
    ...output_path_segments
] {
    let closure = $in
    let $output_file = ['tests' 'assets' 'output-yaml' ...$output_path_segments] | path join

    view source $closure
    | lines | skip | drop | str trim
    | each {$'# ($in)'}
    | str join (char nl)
    | $in + (char nl) + (do $closure) + (char nl)
    | save -fr $output_file

    print $'file created/updated ($output_file)'
}

def 'main release' [] {
    let $git_info = (gh repo view --json description,name | from json);
    let $git_tag = git tag
        | lines
        | prepend '0.0.0'
        | sort -n
        | last
        | split row '.'
        | into int
        | update 2 {$in + 1}
        | str join '.'

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
