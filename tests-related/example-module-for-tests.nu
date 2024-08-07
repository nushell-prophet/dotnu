use example-module-for-tests2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
# ╭─#──┬──────────name──────────┬─type─┬──size───┬───modified────╮
# │ 0  │ LICENSE                │ file │ 1.2 KiB │ 5 months ago  │
# │ 1  │ README.md              │ file │   942 B │ 5 hours ago   │
# │ 2  │ commands-examples      │ dir  │    64 B │ a month ago   │
# │ 3  │ dotnu-internals.nu     │ file │ 5.3 KiB │ 3 hours ago   │
# │ 4  │ dotnu.nu               │ file │ 8.9 KiB │ 3 hours ago   │
# │ 5  │ md_backups             │ dir  │   416 B │ a month ago   │
# │ 6  │ readme-update-scripts  │ dir  │    96 B │ 3 months ago  │
# │ 7  │ repository-maintenance │ dir  │    96 B │ 5 months ago  │
# │ 8  │ temp                   │ dir  │    64 B │ 4 months ago  │
# │ 9  │ tests-for-internals.md │ file │ 4.5 KiB │ a month ago   │
# │ 10 │ tests-related          │ dir  │   352 B │ 6 minutes ago │
# │ 11 │ tools.nu               │ file │   735 B │ a day ago     │
# │ 12 │ zzz_md_backups         │ dir  │    64 B │ 5 hours ago   │
# ╰────┴────────────────────────┴──────┴─────────┴───────────────╯
export def lscustom [] {
    ls
}

# > lscustom | sort-by-custom --option name
def --env 'sort-by-custom' [
    --option: string = 'modified'
] {
    sort-by $option
}

# Example command-3
#
# > command-3
def --wrapped `command-3` [...rest] {
    lscustom | sort-by-custom
}

# > lscustom | first-custom
def "first-custom" --env [] {
    first
}

# > command-5
# ╭─#─┬───────────name────────────┬─type─┬──size───┬───modified───╮
# │ 0 │ LICENSE                   │ file │ 1.2 KiB │ 5 months ago │
# │ 1 │ 0XJCfmatmyHlll03TsWhO6owT │   ❎ │      ❎ │           ❎ │
# ╰───┴───────────────────────────┴──────┴─────────┴──────────────╯
export def 'command-5' [] {
    command-3 'abc' | first-custom | append-random
}
