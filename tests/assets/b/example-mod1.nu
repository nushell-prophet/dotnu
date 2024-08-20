use example-mod2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
# ╭───┬───────────┬──────┬──────────┬────────────╮
# │ # │   name    │ type │   size   │  modified  │
# ├───┼───────────┼──────┼──────────┼────────────┤
# │ 0 │ LICENSE   │ file │  1.2 KiB │ a week ago │
# │ 1 │ README.md │ file │ 10.0 KiB │ 4 days ago │
# │ 2 │ demo.nu   │ file │  3.7 KiB │ 4 days ago │
# │ 3 │ dotnu     │ dir  │    128 B │ 4 days ago │
# │ 4 │ media     │ dir  │     96 B │ 4 days ago │
# │ 5 │ nupm.nuon │ file │    124 B │ 6 days ago │
# │ 6 │ tests     │ dir  │    192 B │ 5 days ago │
# │ 7 │ tools.nu  │ file │  2.3 KiB │ 6 days ago │
# ╰───┴───────────┴──────┴──────────┴────────────╯
export def lscustom [] {
    ls
}


# > command-5
# ╭───┬───────────────────────────╮
# │ # │           name            │
# ├───┼───────────────────────────┤
# │ 0 │ LICENSE                   │
# │ 1 │ n7QOeK7sX1YxIIcRxPOuVZBSd │
# ╰───┴───────────────────────────╯
export def 'command-5' [] {
    command-3 'abc' | first-custom | append-random
}

# This example won't update as its command is not exported
# > lscustom | sort-by-custom --option name
def --env 'sort-by-custom' [
    --option: string = 'modified'
] {
    sort-by $option
}

# Example command-3
#
# This example won't update as its command is not exported
# > command-3
def --wrapped `command-3` [...rest] {
    lscustom | sort-by-custom
}

# This example won't update as its command is not exported
# > lscustom | first-custom
def "first-custom" --env [] {
    first
    | select name
}
