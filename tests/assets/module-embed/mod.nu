use helpers.nu greet-word
export use pub.nu *

export def main [] { greet }

export def greet [] { $"(greet-word) (subject)!" }

# a command with a parameter and private deps, for vars-mode extraction tests
export def greet-loud [--upper] {
    let msg = $"(greet-word) (subject)!"
    if $upper { $msg | str upcase } else { $msg }
}

def subject [] { 'world' }
