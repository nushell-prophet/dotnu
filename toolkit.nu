use ('dotnu' | path join 'commands.nu') *
use dotnu

export def main [] { }

# Run all tests (unit + integration)
export def 'main test' [
    --json # output results as JSON for external consumption
] {
    let unit = main test-unit --quiet=$json
    let integration = main test-integration

    {unit: $unit integration: $integration}
    | if $json { to json --raw } else { }
}

# Run unit tests using nutest
export def 'main test-unit' [
    --json # output results as JSON for external consumption
    --quiet # suppress terminal output (for use when called from main test)
] {
    use ../nutest/nutest

    let display = if ($json or $quiet) { 'nothing' } else { 'terminal' }
    # Match only test_commands to exclude test assets in subdirectories
    nutest run-tests --path tests/ --match-suites 'test_commands' --returns summary --display $display
    | if $json { to json --raw } else { }
}

# Run integration tests
export def 'main test-integration' [
    --json # output results as JSON for external consumption
] {
    [
        (test-dependencies)
        (test-dependencies-keep_builtins)
        (test-embeds-remove)
        (test-embeds-update)
        (test-coverage)
    ]
    # Run numd on README if available
    | if (scope modules | where name == 'numd' | is-not-empty) {
        append (test-numd-readme)
    } else { }
    | if $json { to json --raw } else { }
}

# Run command and save output with source code as header comment
def run-snapshot-test [name: string output_file: string command_src: closure] {
    mkdir ($output_file | path dirname)
    rm -f $output_file

    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    $command_text + (char nl) + (do $command_src)
    | save -f $output_file

    {test: $name file: $output_file}
}

# Test dependencies command
def 'test-dependencies' [] {
    run-snapshot-test 'dependencies' ([tests output-yaml dependencies.yaml] | path join) {
        glob ([tests assets b *] | path join | str replace -a '\' '/')
        | dependencies ...$in
        | to yaml
    }
}

# Test dependencies command with keep-builtins option
def 'test-dependencies-keep_builtins' [] {
    run-snapshot-test 'dependencies --keep-builtins' ([tests output-yaml 'dependencies --keep_bulitins.yaml'] | path join) {
        glob ([tests assets b *] | path join | str replace -a '\' '/')
        | dependencies ...$in --keep-builtins
        | to yaml
    }
}

# Test embeds-remove command
def 'test-embeds-remove' [] {
    let input_file = [tests assets dotnu-capture.nu] | path join
    let output_file = [tests assets dotnu-capture-clean.nu] | path join

    open $input_file
    | dotnu embeds-remove
    | save -f $output_file

    {test: 'embeds-remove' file: $output_file}
}

# Test embeds-update command
def 'test-embeds-update' [] {
    let input_file = [tests assets dotnu-capture.nu] | path join
    let output_file = [tests assets dotnu-capture-updated.nu] | path join

    dotnu embeds-update $input_file --echo
    | save -f $output_file

    {test: 'embeds-update' file: $output_file}
}

# Test coverage: find public API commands without tests
def 'test-coverage' [] {
    run-snapshot-test 'coverage' ([tests output-yaml coverage-untested.yaml] | path join) {
        # Public API from mod.nu
        let public_api = open ([dotnu mod.nu] | path join)
        | lines
        | where $it =~ '^\s+"'
        | each { $in | str trim | str replace -r '^"([^"]+)".*' '$1' }

        # Find untested commands
        let untested = ["dotnu/*.nu" "tests/test_commands.nu" "toolkit.nu"]
        | each { glob $in }
        | flatten
        | dependencies ...$in
        | filter-commands-with-no-tests
        | where caller in $public_api
        | select caller

        # Output as yaml
        {
            public_api_count: ($public_api | length)
            tested_count: (($public_api | length) - ($untested | length))
            untested: ($untested | get caller)
        }
        | to yaml
    }
}

# Test numd on README
def 'test-numd-readme' [] {
    numd run README.md
    {test: 'numd-readme' file: 'README.md'}
}

# Release command to create a new version
export def 'main release' [
    --major (-M) # Bump major version (X.0.0)
    --minor (-m) # Bump minor version (x.Y.0)
] {
    git checkout main

    let git_info = gh repo view --json description,name | from json
    let desc = $git_info | get description

    let parts = git tag | lines | sort --natural | last | default '0.0.0' | split row '.' | into int
    let git_tag = if $major {
        [($parts.0 + 1) 0 0]
    } else if $minor {
        [$parts.0 ($parts.1 + 1) 0]
    } else {
        [$parts.0 $parts.1 ($parts.2 + 1)]
    } | str join '.'

    print $'New version: ($git_tag)'

    # Update nupm.nuon file
    open nupm.nuon
    | update description ($desc | str replace -r $'^($git_info.name) - ' '')
    | update version $git_tag
    | to nuon --indent 2
    | save --force --raw nupm.nuon

    # Update README.md file
    if ('README.md' | path exists) {
        open -r 'README.md'
        | lines
        | update 2 ('<h1 align="center">' + $desc + '</h1>')
        | str join (char nl)
        | $in + (char nl)
        | save -f README.md
    }

    git add nupm.nuon
    git add README.md
    git commit -m $'($git_tag) nupm version'
    git tag $git_tag
    git push origin main --tags

    print $'(ansi green)Release ($git_tag) completed(ansi reset)'
}
