use example-mod2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
# ╭─#─┬──────────name──────────┬─type─┬──size───┬────modified────╮
# │ 0 │ LICENSE                │ file │ 1.2 KiB │ 5 months ago   │
# │ 1 │ README.md              │ file │   942 B │ a day ago      │
# │ 2 │ dotnu-internals.nu     │ file │ 7.1 KiB │ 43 seconds ago │
# │ 3 │ dotnu.nu               │ file │ 9.5 KiB │ 36 seconds ago │
# │ 4 │ tests-for-internals.md │ file │ 4.5 KiB │ a month ago    │
# │ 5 │ tests-related          │ dir  │   288 B │ 15 hours ago   │
# │ 6 │ tools.nu               │ file │ 2.2 KiB │ 15 hours ago   │
# ╰───┴────────────────────────┴──────┴─────────┴────────────────╯
export def lscustom [] {
    ls
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
}

# > command-5
# ╭─#─┬───────────name────────────┬─type─┬──size───┬───modified───╮
# │ 0 │ LICENSE                   │ file │ 1.2 KiB │ 5 months ago │
# │ 1 │ 7HjZto1ykSXWjTnm3A03T2J99 │   ❎ │      ❎ │           ❎ │
# ╰───┴───────────────────────────┴──────┴─────────┴──────────────╯
export def 'command-5' [] {
    command-3 'abc' | first-custom | append-random
}
