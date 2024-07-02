```nushell
> use dotnu.nu *
> use dotnu-internals.nu *
> let yaml_file = (['tests-related' 'numd-internals-parse-docstrings.yaml'] | path join)
> open tests-related/numd-internals.nu | collect | parse-docstrings | save -f $yaml_file

> open $yaml_file | insert examples_parsed {|i| $i.examples | parse-examples} | to yaml
- desc: Generates code for execution in the intermediate script within a given code fence.
  examples: '# > ''ls | sort-by modified -r'' | gen-execute-code --whole_block --fence ''```nu indent-output'' | save z_examples/999_numd_internals/gen-execute-code_0.nu -f'
  command_name: gen-execute-code
  examples_parsed:
  - annotation: ''
    command: '''ls | sort-by modified -r'' | gen-execute-code --whole_block --fence ''```nu indent-output'' | save z_examples/999_numd_internals/gen-execute-code_0.nu -f'
- desc: Expands short options for code block execution to their long forms.
  examples: |-
    # > expand-short-options 'i'
    # indent-output
  command_name: expand-short-options
  examples_parsed:
  - annotation: ''
    command: expand-short-options 'i'
- desc: Escapes symbols to be printed unchanged inside a `print "something"` statement.
  examples: |-
    # > 'abcd"dfdaf" "' | escape-escapes
    # abcd\"dfdaf\" \"
  command_name: escape-escapes
  examples_parsed:
  - annotation: ''
    command: '''abcd"dfdaf" "'' | escape-escapes'
- desc: Generates an unique identifier for code blocks in markdown to distinguish their output.
  examples: |-
    # > numd-block 3
    # code-block-starting-line-in-original-md-3
  command_name: numd-block
  examples_parsed:
  - annotation: ''
    command: numd-block 3
- desc: Checks if the last line of the input ends with a semicolon or certain keywords to determine if appending ` | print` is possible.
  examples: |-
    # > ends-with-definition 'let a = ls'
    # true
    #
    # > ends-with-definition 'ls'
    # false
  command_name: ends-with-definition
  examples_parsed:
  - annotation: ''
    command: ends-with-definition 'let a = ls'
  - annotation: ''
    command: ends-with-definition 'ls'
- desc: Generates indented output for better visual formatting.
  examples: |-
    # > 'ls' | gen-indented-output
    # ls | table | into string | lines | each {$'//  ($in)' | str trim --right} | str join (char nl)
  command_name: gen-indented-output
  examples_parsed:
  - annotation: ''
    command: '''ls'' | gen-indented-output'
- desc: Generates a print statement for capturing command output.
  examples: |-
    # > 'ls' | gen-print-in
    # ls | print; print ''
  command_name: gen-print-in
  examples_parsed:
  - annotation: ''
    command: '''ls'' | gen-print-in'
- desc: Generates a try-catch block to handle errors in the current Nushell instance.
  examples: |-
    # > 'ls' | gen-catch-error-in-current-instance
    # try {ls} catch {|error| $error}
  command_name: gen-catch-error-in-current-instance
  examples_parsed:
  - annotation: ''
    command: '''ls'' | gen-catch-error-in-current-instance'
- desc: Executes the command outside to obtain a formatted error message if any.
  examples: |-
    # > 'ls' | gen-catch-error-outside
    # /Users/user/.cargo/bin/nu -c "ls"| complete | if ($in.exit_code != 0) {get stderr} else {get stdout}
  command_name: gen-catch-error-outside
  examples_parsed:
  - annotation: ''
    command: '''ls'' | gen-catch-error-outside'
- desc: Generates a fenced code block for output with a specific format.
  examples: '# We use a combination of "\n" and (char nl) here for itermid script formatting aesthetics'
  command_name: gen-fence-output-numd
  examples_parsed: []
- desc: Parses options from a code fence and returns them as a list.
  examples: |-
    # > '```nu no-run, t' | parse-options-from-fence
    # ╭────────╮
    # │ no-run │
    # │ try    │
    # ╰────────╯
  command_name: parse-options-from-fence
  examples_parsed:
  - annotation: ''
    command: '''```nu no-run, t'' | parse-options-from-fence'
- desc: Modifies a path by adding a prefix, suffix, extension, or parent directory.
  examples: |-
    # > 'numd/capture.nu' | path-modify --extension '.md' --prefix 'pref_' --suffix '_suf' --parent_dir abc
    # numd/abc/pref_capture_suf.nu.
  command_name: path-modify
  examples_parsed:
  - annotation: ''
    command: '''numd/capture.nu'' | path-modify --extension ''.md'' --prefix ''pref_'' --suffix ''_suf'' --parent_dir abc'
- desc: Generates a timestamp string in the format YYYYMMDD_HHMMSS.
  examples: |-
    # > tstamp
    # 20240527_111215
  command_name: tstamp
  examples_parsed:
  - annotation: ''
    command: tstamp
```
