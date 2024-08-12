use small-talk.nu neutral-question

# Output greeting!
#
# Say hello to Maxim
# > hello Maxim
# hello Maxim!
#
# Say hello to Darren
# > hello Darren
# hello Darren!
export def hello [name: string] {
    $"hello ($name)!"
}

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
# - have you heard about the fancy new shell?
export def main [] {
    [ (hello Darren) (hi Maxim) (neutral-question) ]
    | each {'- ' + $in}
    | str join (char nl)
}
