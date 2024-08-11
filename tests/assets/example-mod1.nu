use example-mod2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
export def lscustom [] {
    ls
}


# > command-5
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
