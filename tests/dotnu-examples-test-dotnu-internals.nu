use ../dotnu/dotnu-internals.nu *

export def `test-variable-definitions-to-record-0` [] {
    "let $quiet = false; let $no_timestamp = false" | variable-definitions-to-record | to nuon
}

export def `test-variable-definitions-to-record-1` [] {
    "let $a = 'b'\nlet $c = 'd'\n\n#comment" | variable-definitions-to-record | to nuon
}

export def `test-extract-command-name-0` [] {
    'export def --env "test" --wrapped' | lines | last | extract-command-name
}

export def `test-escape-escapes-0` [] {
    'abcd"dfdaf" "' | escape-escapes
}

export def `test-nu-completion-command-name-0` [] {
    nu-completion-command-name 'dotnu extract-command tests/assets/example-mod1.nu' | first 3
}

export def `test-extract-module-commands-0` [] {
    extract-module-commands tests/assets/example-mod1.nu | first 3
}

export def `test-extract-module-commands-1` [] {
    extract-module-commands --definitions_only tests/assets/example-mod1.nu | first 3
}

export def `test-join-next-0` [] {
    [[caller callee step filename_of_caller]; [a b 0 test] [b c 0 test]] | join-next $in | to nuon
}
