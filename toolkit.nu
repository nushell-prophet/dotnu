use ('dotnu' | path join 'commands.nu') *
use dotnu

export def main [] { }

# Run all tests (unit + integration)
#
# Output mode is auto-detected: when stdout is a terminal you get the human view
# (failures + a summary line); when it is piped or redirected you get machine-readable
# JSON. Force either with --json / --pretty.
export def 'main test' [
    --json # force machine-readable JSON output even on a terminal
    --pretty # force the human view even when output is piped
    --all # human view: also list passing tests (default shows only non-passing)
    --update # accept changes: stage modified integration test files
    --fail # exit with non-zero code if any tests fail (for CI)
] {
    let results = (collect-unit-results) | append (collect-integration-results --update=$update)

    if (machine-mode --json=$json --pretty=$pretty) {
        print ($results | to json --raw)
    } else {
        print-human $results --all=$all --update=$update
    }

    if $fail and ($results | where status == 'failed' | is-not-empty) {
        exit 1
    }
}

# Run unit tests using nutest
#
# Machine (JSON / piped) rows use the flat schema:
#   {type: 'unit', name, status: 'passed'|'failed', file: null, message}
# Note: status is 'passed'|'failed', NOT nutest's 'PASS'|'FAIL' 'result' column.
# message holds the assertion text on failure, null otherwise.
export def 'main test-unit' [
    --json # force machine-readable JSON output even on a terminal
    --pretty # force the human view even when output is piped
    --all # human view: also list passing tests (default shows only failures)
] {
    let flat = collect-unit-results
    if (machine-mode --json=$json --pretty=$pretty) {
        $flat | to json --raw
    } else {
        print-human $flat --all=$all
    }
}

# Run integration tests
#
# These are snapshot tests: each test runs a command and saves the output to a file.
# The files are committed to git, so `git diff` reveals any behavioral changes.
# Machine rows use the flat schema:
#   {type: 'integration', name, status: 'passed'|'changed'|'failed', file, message}
export def 'main test-integration' [
    --json # force machine-readable JSON output even on a terminal
    --pretty # force the human view even when output is piped
    --all # human view: also list passing tests (default shows only non-passing)
    --update # accept changes: stage modified files in git
] {
    let flat = collect-integration-results --update=$update
    if (machine-mode --json=$json --pretty=$pretty) {
        $flat | to json --raw
    } else {
        print-human $flat --all=$all --update=$update
    }
}

# Decide whether to emit machine-readable data instead of the human view.
# Why: agents capture stdout through a pipe, humans read it in a terminal.
# Not $nu.is-interactive because: it reports REPL-ness, not human-ness — it is false for
# any `nu toolkit.nu ...` script run (human or agent) and true for an agent driving the
# nushell MCP, so it detects the opposite of what we need. is-terminal --stdout is the tty test.
def machine-mode [--json --pretty]: nothing -> bool {
    if $pretty { return false } # Not-piped override wins over everything
    if $json { return true }
    not (is-terminal --stdout)
}

# Collect unit test results as flat rows (no output side effects)
def collect-unit-results []: nothing -> table {
    use ../nutest/nutest

    nutest run-tests --path tests/ --match-suites 'test_commands' --returns table --display nothing
    | each {|row|
        let status = if $row.result == 'PASS' { 'passed' } else { 'failed' }
        let message = if $status == 'failed' {
            let msgs = $row.output | each {|o| $o.msg? } | compact
            if ($msgs | is-empty) { null } else { $msgs | str join '; ' }
        } else { null }
        {type: 'unit' name: $row.test status: $status file: null message: $message}
    }
}

# Collect integration (snapshot) test results as flat rows.
# The `run-snapshot-test` helper embeds the generating code as header comments,
# making each snapshot self-documenting.
def collect-integration-results [--update]: nothing -> table {
    let results = [
        (
            run-snapshot-test 'dependencies' ([tests output-yaml dependencies.yaml] | path join) {
                glob ([tests assets b *] | path join | str replace -a '\' '/')
                | dependencies ...$in
                | sort-by caller callee step
                | to yaml
            }
        )
        (
            run-snapshot-test 'dependencies --keep-builtins' ([tests output-yaml 'dependencies --keep_builtins.yaml'] | path join) {
                glob ([tests assets b *] | path join | str replace -a '\' '/')
                | dependencies ...$in --keep-builtins
                | sort-by caller callee step
                | to yaml
            }
        )
        (
            run-snapshot-test 'embeds-remove' ([tests assets dotnu-capture-clean.nu] | path join) {
                open ([tests assets dotnu-capture.nu] | path join)
                | dotnu embeds-remove
            }
        )
        (
            run-snapshot-test 'embeds-update' ([tests assets dotnu-capture-updated.nu] | path join) {
                dotnu embeds-update ([tests assets dotnu-capture.nu] | path join) --echo
            }
        )
        (
            run-snapshot-test 'coverage' ([tests output-yaml coverage-untested.nuon] | path join) {
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

                # Why: serialize as nuon, not yaml — `to yaml`'s list indentation
                # changed between nushell versions and drifted this snapshot on
                # identical data. nuon compares the parsed structure stably.
                {
                    public_api_count: ($public_api | length)
                    tested_count: (($public_api | length) - ($untested | length))
                    untested: ($untested | get caller)
                }
                | to nuon --indent 2
            }
        )
    ]
        # Run numd on README if available
        | if (scope modules | where name == 'numd' | is-not-empty) {
            append (run-snapshot-test 'numd-readme' 'README.md' { numd run README.md })
        } else { }

    if $update {
        let changed = $results | where status == 'changed'
        if ($changed | is-not-empty) {
            $changed | each {|r|
                ^git add $r.file
                # Why: -e (stderr) so staging notes never corrupt the JSON on stdout in machine mode
                print -e $"(ansi green)Staged:(ansi reset) ($r.file)"
            }
        }
    }

    $results
}

# Print the human view: non-passing tests (or all with --all), then a summary line.
# Returns nothing so no wide table auto-renders and truncates the verdict column.
def print-human [flat: table --all --update] {
    let to_show = if $all { $flat } else { $flat | where status != 'passed' }
    $to_show | each {|r| print-test-result $r }
    print-summary $flat --update=$update
}

# Print the N passed, M failed [, K changed] headline
def print-summary [flat: table --update] {
    let passed = $flat | where status == 'passed' | length
    let failed = $flat | where status == 'failed' | length
    let changed = $flat | where status == 'changed' | length
    let total = $flat | length

    let parts = [
        $"(ansi green_bold)($passed) passed(ansi reset)"
        $"(ansi red_bold)($failed) failed(ansi reset)"
    ] | append (if $changed > 0 { [$"(ansi yellow_bold)($changed) changed(ansi reset)"] } else { [] })

    print $"($parts | str join ', ') \(($total) total\)"
    if $changed > 0 and not $update {
        print $"(ansi attr_dimmed)Run with --update to accept changes(ansi reset)"
    }
}

# Print a single test result with status indicator (and the assertion on failure)
def print-test-result [result: record] {
    let icon = match $result.status {
        'passed' => $"(ansi green)✓(ansi reset)"
        'failed' => $"(ansi red)✗(ansi reset)"
        'changed' => $"(ansi yellow)~(ansi reset)"
        _ => "?"
    }
    let suffix = if $result.file != null { $" (ansi attr_dimmed)\(($result.file)\)(ansi reset)" } else { "" }
    print $"  ($icon) ($result.name)($suffix)"
    if $result.status == 'failed' and ($result.message? | is-not-empty) {
        print $"      (ansi red)($result.message)(ansi reset)"
    }
}

# Run command and save output with source code as header comment
# Returns: {type: 'integration', name, status: 'passed'|'changed'|'failed', file, message}
def run-snapshot-test [name: string output_file: string command_src: closure] {
    mkdir ($output_file | path dirname)

    let command_text = view source $command_src
        | lines | skip | drop | str trim
        | each { $'# ($in)' }
        | str join (char nl)

    try {
        $command_text + (char nl) + (do $command_src)
        | save -f $output_file

        # Check git diff to determine status.
        # Why: `git diff` ignores untracked files, so a brand-new snapshot would
        # report 'passed' without ever being compared to a baseline. Treat an
        # untracked file as 'changed' so it surfaces and `--update` stages it.
        let tracked = do { ^git ls-files --error-unmatch $output_file } | complete | get exit_code | $in == 0
        let status = if not $tracked {
            'changed'
        } else {
            let diff_result = do { ^git diff --quiet $output_file } | complete
            if $diff_result.exit_code == 0 { 'passed' } else { 'changed' }
        }

        {type: 'integration' name: $name status: $status file: $output_file message: null}
    } catch {|err|
        {type: 'integration' name: $name status: 'failed' file: $output_file message: $err.msg}
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
    git push source main --tags

    print $'(ansi green)Release ($git_tag) completed(ansi reset)'
}
