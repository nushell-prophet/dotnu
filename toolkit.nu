use ('dotnu' | path join 'commands.nu') *
use dotnu

export def main [] { }

# Run all tests (unit + integration)
export def 'main test' [
    --json # output results as JSON for external consumption
    --update # accept changes: stage modified integration test files
    --fail # exit with non-zero code if any tests fail (for CI)
] {
    if not $json { print $"(ansi attr_dimmed)Unit tests(ansi reset)" }
    let unit = main test-unit --json=$json
    if not $json { print $"(ansi attr_dimmed)Integration tests(ansi reset)" }
    let integration = main test-integration --json=$json --update=$update

    # Parse JSON if needed
    let unit_data = if $json { $unit | from json } else { $unit }
    let integration_data = if $json { $integration | from json } else { $integration }
    let results = $unit_data | append $integration_data

    # Print summary
    let passed = $results | where status == 'passed' | length
    let failed = $results | where status == 'failed' | length
    let changed = $results | where status == 'changed' | length
    let total = $results | length

    if not $json {
        print ""
        print $"(ansi green_bold)($passed) passed(ansi reset), (ansi red_bold)($failed) failed(ansi reset), (ansi yellow_bold)($changed) changed(ansi reset) \(($total) total\)"
        if $changed > 0 and not $update {
            print $"(ansi attr_dimmed)Run with --update to accept changes(ansi reset)"
        }
    }

    if $fail and $failed > 0 {
        if $json { print ($results | to json --raw) }
        exit 1
    }

    if $json { $results | to json --raw }
}

# Run unit tests using nutest
export def 'main test-unit' [
    --json # output results as JSON for external consumption
] {
    use ../nutest/nutest

    # Get detailed table from nutest
    let results = nutest run-tests --path tests/ --match-suites 'test_commands' --returns table --display nothing

    # Convert to flat table format
    let flat = $results | each { |row|
        let status = if $row.result == 'PASS' { 'passed' } else { 'failed' }
        {type: 'unit' name: $row.test status: $status file: null}
    }

    if not $json {
        $flat | each { |r| print-test-result $r }
    }

    if $json { $flat | to json --raw } else { $flat }
}

# Run integration tests
#
# These are snapshot tests: each test runs a command and saves the output to a file.
# The files are committed to git, so `git diff` reveals any behavioral changes.
# The `run-snapshot-test` helper embeds the generating code as header comments,
# making each snapshot self-documenting.
export def 'main test-integration' [
    --json # output results as JSON for external consumption
    --update # accept changes: stage modified files in git
] {
    let results = [
        (run-snapshot-test 'dependencies' ([tests output-yaml dependencies.yaml] | path join) {
            glob ([tests assets b *] | path join | str replace -a '\' '/')
            | dependencies ...$in
            | to yaml
        })
        (run-snapshot-test 'dependencies --keep-builtins' ([tests output-yaml 'dependencies --keep_builtins.yaml'] | path join) {
            glob ([tests assets b *] | path join | str replace -a '\' '/')
            | dependencies ...$in --keep-builtins
            | to yaml
        })
        (run-snapshot-test 'embeds-remove' ([tests assets dotnu-capture-clean.nu] | path join) {
            open ([tests assets dotnu-capture.nu] | path join)
            | dotnu embeds-remove
        })
        (run-snapshot-test 'embeds-update' ([tests assets dotnu-capture-updated.nu] | path join) {
            dotnu embeds-update ([tests assets dotnu-capture.nu] | path join) --echo
        })
        (run-snapshot-test 'coverage' ([tests output-yaml coverage-untested.yaml] | path join) {
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
        })
    ]
    # Run numd on README if available
    | if (scope modules | where name == 'numd' | is-not-empty) {
        append (run-snapshot-test 'numd-readme' 'README.md' { numd run README.md })
    } else { }

    if not $json {
        $results | each { |r| print-test-result $r }
    }

    if $update {
        let changed = $results | where status == 'changed'
        if ($changed | is-not-empty) {
            $changed | each { |r|
                ^git add $r.file
                print $"(ansi green)Staged:(ansi reset) ($r.file)"
            }
        }
    }

    if $json { $results | to json --raw } else { $results }
}

# Print a single test result with status indicator
def print-test-result [result: record] {
    let icon = match $result.status {
        'passed' => $"(ansi green)✓(ansi reset)"
        'failed' => $"(ansi red)✗(ansi reset)"
        'changed' => $"(ansi yellow)~(ansi reset)"
        _ => "?"
    }
    let suffix = if $result.file != null { $" (ansi attr_dimmed)\(($result.file)\)(ansi reset)" } else { "" }
    print $"  ($icon) ($result.name)($suffix)"
}

# Run command and save output with source code as header comment
# Returns: {type: 'integration', name: string, status: 'passed'|'changed'|'failed', file: string}
def run-snapshot-test [name: string, output_file: string, command_src: closure] {
    mkdir ($output_file | path dirname)

    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    try {
        $command_text + (char nl) + (do $command_src)
        | save -f $output_file

        # Check git diff to determine status
        let diff_result = do { ^git diff --quiet $output_file } | complete
        let status = if $diff_result.exit_code == 0 { 'passed' } else { 'changed' }

        {type: 'integration' name: $name status: $status file: $output_file}
    } catch { |err|
        {type: 'integration' name: $name status: 'failed' file: $output_file}
    }
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
