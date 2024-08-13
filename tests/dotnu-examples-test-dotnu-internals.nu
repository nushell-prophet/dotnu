use ../dotnu/dotnu-internals.nu *

export def `variable-definitions-to-record-0-test` [] {
    "let $quiet = false; let $no_timestamp = false" | variable-definitions-to-record | to nuon
}

export def `variable-definitions-to-record-1-test` [] {
    "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record | to nuon
}

export def `extract-command-name-0-test` [] {
    'export def --env "test" --wrapped' | lines | last | extract-command-name
}

export def `escape-for-quotes-0-test` [] {
    'abcd"dfdaf" "' | escape-for-quotes
}

export def `nu-completion-command-name-0-test` [] {
    nu-completion-command-name 'dotnu extract-command tests/assets/b/example-mod1.nu' | first 3
}

export def `extract-module-commands-0-test` [] {
    extract-module-commands tests/assets/b/example-mod1.nu | first 3
}

export def `extract-module-commands-1-test` [] {
    extract-module-commands --definitions_only tests/assets/b/example-mod1.nu | first 3
}

export def `join-next-0-test` [] {
    [[caller callee step filename_of_caller]; [a b 0 test] [b c 0 test]] | join-next $in | to nuon
}
