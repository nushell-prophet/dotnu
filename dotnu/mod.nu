export use commands.nu [
    "dependencies"
    "embed-add"
    "embeds-capture-start"
    "embeds-capture-stop"
    "embeds-remove"
    "embeds-setup"
    "embeds-update"
    "extract-command-code"
    "filter-commands-with-no-tests"
    "generate-numd"
    "list-exported-commands"
    "module-commands-code-to-record"
    "set-x"
]

use ('..' | path join tests nupm utils dirs.nu) find-root
