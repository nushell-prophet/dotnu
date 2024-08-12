use example-mod2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
# ╭─#─┬──────name──────┬─type─┬──size───┬───modified───╮
# │ 0 │ LICENSE        │ file │ 1.2 KiB │ 5 months ago │
# │ 1 │ README.md      │ file │ 5.0 KiB │ 16 hours ago │
# │ 2 │ dotnu          │ dir  │   128 B │ 16 hours ago │
# │ 3 │ nupm.nuon      │ file │   123 B │ 2 days ago   │
# │ 4 │ tests          │ dir  │   192 B │ 2 days ago   │
# │ 5 │ tools.nu       │ file │ 2.4 KiB │ 2 days ago   │
# │ 6 │ zzz_md_backups │ dir  │   448 B │ 16 hours ago │
# ╰───┴────────────────┴──────┴─────────┴──────────────╯
export def lscustom [] {
    ls
}


# > command-5
# ╭─#─┬───────────name────────────╮
# │ 0 │ LICENSE                   │
# │ 1 │ IZMa4BrhlIzQgt38R22S9CGPG │
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
