use ask.nu question
use hello.nu

# Greet informally
#
# > say hi there
# hi there!
export def hi [where: string] {
    $"hi ($where)!"
}

# > say
# - hello Darren!
# - hi Maxim!
# - have you heard about a fancy new shell?
export def main [] {
    [ (hello Darren) (hi Maxim) (question) ]
    | each {'- ' + $in}
    | str join (char nl)
}
