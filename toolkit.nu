use ('dotnu' | path join 'commands.nu') *
use dotnu

export def main [] { }

# Run all tests (unit tests + integration tests)
export def 'main testing' [
    --json # output results as JSON for external consumption
] {
    let unit = main testing-unit --quiet=$json
    let integration = main testing-integration

    {unit: $unit integration: $integration}
    | if $json { to json --raw } else { }
}

# Run unit tests using nutest
export def 'main testing-unit' [
    --json # output results as JSON for external consumption
    --quiet # suppress terminal output (for use when called from main testing)
] {
    use ../nutest/nutest

    let display = if ($json or $quiet) { 'nothing' } else { 'terminal' }
    # Match only test_commands to exclude test assets in subdirectories
    nutest run-tests --path tests/ --match-suites 'test_commands' --returns summary --display $display
    | if $json { to json --raw } else { }
}

# Run integration tests
export def 'main testing-integration' [
    --json # output results as JSON for external consumption
] {
    [
        (test-dependencies)
        (test-dependencies-keep_builtins)
        (test-embeds-remove)
        (test-embeds-update)
    ]
    # Run numd on README if available
    | if (scope modules | where name == 'numd' | is-not-empty) {
        append (test-numd-readme)
    } else { }
    | if $json { to json --raw } else { }
}

# Main test function that runs all tests (alias for testing)
export def 'main test' [] {
    main testing
}

# Test dependencies command
def 'test-dependencies' [] {
    let output_file = ['tests' 'output-yaml' 'dependencies.yaml'] | path join

    mkdir ($output_file | path dirname)
    rm -f $output_file

    let command_src = {
        glob ([tests assets b *] | path join | str replace -a '\' '/')
        | dependencies ...$in
        | to yaml
    }

    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    $command_text + (char nl) + (do $command_src)
    | save -f $output_file

    {test: 'dependencies' file: $output_file}
}

# Test dependencies command with keep-builtins option
def 'test-dependencies-keep_builtins' [] {
    let output_file = ['tests' 'output-yaml' 'dependencies --keep_bulitins.yaml'] | path join

    mkdir ($output_file | path dirname)
    rm -f $output_file

    let command_src = {
        glob ([tests assets b *] | path join | str replace -a '\' '/')
        | dependencies ...$in --keep-builtins
        | to yaml
    }

    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    $command_text + (char nl) + (do $command_src)
    | save -f $output_file

    {test: 'dependencies --keep-builtins' file: $output_file}
}

# Test embeds-remove command
def 'test-embeds-remove' [] {
    let input_file = 'tests/assets/dotnu-capture.nu'
    let output_file = 'tests/assets/dotnu-capture-clean.nu'

    open $input_file
    | dotnu embeds-remove
    | save -f $output_file

    {test: 'embeds-remove' file: $output_file}
}

# Test embeds-update command
def 'test-embeds-update' [] {
    let input_file = 'tests/assets/dotnu-capture.nu'
    let output_file = 'tests/assets/dotnu-capture-updated.nu'

    dotnu embeds-update $input_file --echo
    | save -f $output_file

    {test: 'embeds-update' file: $output_file}
}

# Test numd on README
def 'test-numd-readme' [] {
    numd run README.md --no-backup
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
