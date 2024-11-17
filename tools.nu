use ( 'dotnu' | path join 'commands.nu' ) *

def main [] {}

def 'main test' [] {
    test-parse-docstrings
    test-dependencies
    test-dependencies-keep_builtins
    test-execute-update-examples-no-output

    # Not everyone yet uses numd
    if (help modules | where name == 'numd' | is-not-empty) {
        numd run README.md
    }
}

def 'main test-nupm' [] {
    overlay use tests/nupm/test.nu --prefix as nupm
    nupm test
}

def 'test-parse-docstrings' [] {
    [tests assets '**' '*.nu']
    | path join
    | glob $in
    | each {test-parse-docstrings-output-yaml}
}

def 'test-parse-docstrings-output-yaml' [] {
    let $path = $in
    {
        open $path
        | parse-docstrings
        | to yaml
    }
    | do_closure_save_results $'parse-docstrings-($path | path parse | get stem).yaml'
}

def 'test-dependencies' [] {
    {
        glob ([tests assets b *] | path join)
        | dependencies ...$in
        | to yaml
    }
    | do_closure_save_results 'dependencies.yaml'
}

def 'test-dependencies-keep_builtins' [] {
    {
        glob ([tests assets b *] | path join)
        | dependencies ...$in --keep-builtins
        | to yaml
    }
    | do_closure_save_results 'dependencies --keep_bulitins.yaml'
}

def 'test-execute-update-examples-no-output' [] {
    {
        [tests assets c hello-no-output.nu]
        | path join
        | path expand
        | update-docstring-examples $in --no-git-check --echo
    }
    | do_closure_save_results hello-no-output.txt
}

def do_closure_save_results [
    ...output_path_segments
] {
    let $closure = $in
    let $output_file = ['tests' 'output-yaml' ...$output_path_segments] | path join

    if ($output_file | path exists) {rm $output_file}

    view source $closure
    | lines | skip | drop | str trim
    | each {$'# ($in)'}
    | str join (char nl)
    | $in + (char nl) + (do $closure)
    | save -fr $output_file

    print $'( ansi green )file updated( ansi reset ) ($output_file)'
}

def 'main release' [] {
    let $git_info = gh repo view --json description,name | from json
    let $git_tag = git tag
        | lines
        | prepend '0.0.0'
        | sort -n
        | last
        | split row '.'
        | into int
        | update 2 {$in + 1}
        | str join '.'

    let $desc = $git_info | get description

    open nupm.nuon
    | update description ($desc | str replace -r $'^($git_info.name) - ' '')
    | update version $git_tag
    | save -f nupm.nuon

    'README.md'
    | if ($in | path exists) {
        open -r
    } else {"\n"}
    | lines
    | update 2 ('<h1 align="center">' + $desc + '</h1>')
    # | update 2 $'# ($desc)'
    | str join (char nl)
    | $in + (char nl)
    | save -f README.md

    prettier README.md -w

    git add nupm.nuon
    git add README.md
    git commit -m $'($git_tag) nupm version'
    git tag $git_tag
}
