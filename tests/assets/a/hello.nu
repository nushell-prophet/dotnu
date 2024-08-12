# Output greeting!
#
# Say hello to Maxim
# > hello Maxim
# hello Maxim!
#
# Say hello to Darren
# and capitlize letters
# > hello Darren
# | str capitalize
# Hello Darren!
export def main [name: string] {
    $"hello ($name)!"
}
