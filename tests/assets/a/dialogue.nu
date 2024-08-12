use small-talk.nu neutral-question
use hello.nu

# Greet informally
#
# > hi there
# hi there!
export def hi [where: string] {
    $"hi ($where)!"
}

# > dialogue
# - hello Darren!
# - hi Maxim!
# - have you heard about a fancy new shell?
export def main [] {
    [ (hello Darren) (hi Maxim) (neutral-question) ]
    | each {'- ' + $in}
    | str join (char nl)
}
