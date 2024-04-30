export def main []: nothing -> nothing {}

export def command-1 [] {
    main
}

def --env 'command-2' [] {
    command-1 | something | command-1
}

def --wrapped command-3 [...rest] {
    command-2
}

def "command-4" [] {
    command-2 | command-1
}

export def 'command-5' [] {
    command-3 'abc' | command-4
}
