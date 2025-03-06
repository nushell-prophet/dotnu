export use commands.nu [
    dependencies
    filter-commands-with-no-tests
    parse-docstrings
    update-docstring-examples
    set-x
    generate-nupm-tests
    generate-numd
    extract-command-code
    list-main-commands
    embeds-update
    embeds-remove
    'embed-add'
    'embeds-setup'
    'embeds-capture-start'
    'embeds-capture-stop'
]

use ('..' | path join tests nupm utils dirs.nu) find-root
