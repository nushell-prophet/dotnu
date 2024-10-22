export use all-dotnu.nu [
    dependencies
    filter-commands-with-no-tests
    parse-docstrings
    update-docstring-examples
    set-x
    generate-nupm-tests
    generate-numd
    extract-command-code
    list-main-commands
]

use ('..' | path join tests nupm utils dirs.nu) find-root
