use example-mod2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
# ╭─#─┬────────name────────┬─type─┬──size───┬────modified────╮
# │ 0 │ LICENSE            │ file │ 1.2 KiB │ 5 months ago   │
# │ 1 │ README.md          │ file │   942 B │ a day ago      │
# │ 2 │ dotnu-internals.nu │ file │ 7.1 KiB │ 24 minutes ago │
# │ 3 │ dotnu.nu           │ file │ 9.5 KiB │ 2 minutes ago  │
# │ 4 │ tests/assets      │ dir  │   288 B │ 33 seconds ago │
# │ 5 │ tools.nu           │ file │ 2.2 KiB │ 16 hours ago   │
# ╰───┴────────────────────┴──────┴─────────┴────────────────╯
export def lscustom [] {
    ls
}


# > command-5
# ╭─#─┬───────────name────────────┬─type─┬──size───┬───modified───╮
# │ 0 │ LICENSE                   │ file │ 1.2 KiB │ 5 months ago │
# │ 1 │ WW5DW7di1FEYWYdZ7P3ETt1VI │   ❎ │      ❎ │           ❎ │
# ╰───┴───────────────────────────┴──────┴─────────┴──────────────╯
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
