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

# Run integration tests (legacy tests)
export def 'main testing-integration' [] {
    print "Running test-dependencies..."
    test-dependencies

    print "Running test-dependencies-keep_builtins..."
    test-dependencies-keep_builtins

    print "Running test-embeds-remove..."
    test-embeds-remove

    print "Running test-embeds-update..."
    test-embeds-update

    # Not everyone yet uses numd
    if (help modules | where name == 'numd' | is-not-empty) {
        print "Running numd tests..."
        numd run README.md
    }

    print $"(ansi green)All integration tests passed(ansi reset)"
}

# Main test function that runs all tests (alias for testing)
export def 'main test' [] {
    main testing
}

# Test for nupm functionality
def 'main test-nupm' [] {
    print "Testing nupm..."
    overlay use --prefix tests/nupm/test.nu as nupm
    nupm test
}

# Test dependencies command
def 'test-dependencies' [] {
    print "Testing basic dependencies command..."

    # Create output directory if it doesn't exist
    let output_dir = ['tests' 'output-yaml'] | path join
    if not ($output_dir | path exists) {
        mkdir $output_dir
    }

    # Define output file path
    let output_file = [$output_dir 'dependencies.yaml'] | path join

    # Remove old output file if exists
    if ($output_file | path exists) {
        rm $output_file
    }

    # Run the command and get its source code
    let command_src = {
        glob (
            [tests assets b *]
            | path join
            | str replace -a '\' '/' # fix for windows
        )
        | dependencies ...$in
        | to yaml
    }

    # Get the command source as a string
    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    # Execute the command
    let command_result = do $command_src

    # Save both the command and result to the output file
    $command_text + (char nl) + $command_result
    | save -fr $output_file

    print $'(ansi green)file updated(ansi reset) ($output_file)'
}

# Test dependencies command with keep-builtins option
def 'test-dependencies-keep_builtins' [] {
    print "Testing dependencies command with keep-builtins option..."

    # Create output directory if it doesn't exist
    let output_dir = ['tests' 'output-yaml'] | path join
    if not ($output_dir | path exists) {
        mkdir $output_dir
    }

    # Define output file path
    let output_file = [$output_dir 'dependencies --keep_bulitins.yaml'] | path join

    # Remove old output file if exists
    if ($output_file | path exists) {
        rm $output_file
    }

    # Run the command and get its source code
    let command_src = {
        glob (
            [tests assets b *]
            | path join
            | str replace -a '\' '/' # fix for windows
        )
        | dependencies ...$in --keep-builtins
        | to yaml
    }

    # Get the command source as a string
    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    # Execute the command
    let command_result = do $command_src

    # Save both the command and result to the output file
    $command_text + (char nl) + $command_result
    | save -fr $output_file

    print $'(ansi green)file updated(ansi reset) ($output_file)'
}

# Test embeds-remove command
def 'test-embeds-remove' [] {
    print "Testing embeds-remove command..."

    # Define input and output files
    let input_file = 'tests/assets/dotnu-capture.nu'
    let output_file = 'tests/assets/dotnu-capture-clean.nu'

    # Run the command and save the result
    open $input_file
    | dotnu embeds-remove
    | save -f $output_file

    print $'(ansi green)file updated(ansi reset) ($output_file)'
}

# Test embeds-update command
def 'test-embeds-update' [] {
    print "Testing embeds-update command..."

    # Define input and output files
    let input_file = 'tests/assets/dotnu-capture.nu'
    let output_file = 'tests/assets/dotnu-capture-updated.nu'

    # Run the command and save the result
    dotnu embeds-update $input_file --echo
    | save -f $output_file

    print $'(ansi green)file updated(ansi reset) ($output_file)'
}

# Release command to create a new version
def 'main release' [] {
    print "Preparing release..."

    # Get repository information
    let git_info = gh repo view --json description,name | from json

    # Generate new version tag
    let git_tag = git tag
    | lines
    | prepend '0.0.0'
    | sort -n
    | last
    | split row '.'
    | into int
    | update 2 { $in + 1 }
    | str join '.'

    print $'New version: ($git_tag)'

    # Get description
    let desc = $git_info | get description

    # Update nupm.nuon file
    print "Updating nupm.nuon..."
    open nupm.nuon
    | update description ($desc | str replace -r $'^($git_info.name) - ' '')
    | update version $git_tag
    | save -f nupm.nuon

    # Update README.md file
    print "Updating README.md..."
    if ('README.md' | path exists) {
        open -r 'README.md'
        | lines
        | update 2 ('<h1 align="center">' + $desc + '</h1>')
        | str join (char nl)
        | $in + (char nl)
        | save -f README.md
    } else {
        $'\n<h1 align="center">($desc)</h1>\n'
        | save -f README.md
    }

    # Run prettier on README
    print "Running prettier on README.md..."
    prettier README.md -w

    # Commit and tag
    print "Committing changes and creating tag..."
    git add nupm.nuon
    git add README.md
    git commit -m $'($git_tag) nupm version'
    git tag $git_tag

    print $'(ansi green)Release ($git_tag) completed(ansi reset)'
}
