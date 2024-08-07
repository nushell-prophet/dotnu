use example-module-for-tests2.nu *

export def main []: nothing -> nothing {}

# Just like `ls` but longer to type
#
# > lscustom
export def lscustom [] {
    ls
}

# > lscustrom | sort-by-custom --option name
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

# > lscustrom | first-custom
def "first-custom" --env [] {
    first
}

# > command-5
export def 'command-5' [] {
    command-3 'abc' | first-custom | append-random
}
