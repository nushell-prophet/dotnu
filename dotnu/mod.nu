export use commands.nu [
    dependencies
    filter-commands-with-no-tests
    set-x
    generate-numd
    extract-command-code
    module-commands-code-to-record
    list-main-commands
    embeds-update
    embeds-remove
    'embed-add'
    'embeds-setup'
    'embeds-capture-start'
    'embeds-capture-stop'
]

use ('..' | path join tests nupm utils dirs.nu) find-root
