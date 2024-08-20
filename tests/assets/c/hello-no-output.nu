# Output greeting!
#
# Say hello to Maxim
# > hello-no-output Maxim
#
# Say hello to Darren
# and capitlize letters
# > hello-no-output Darren
# | str capitalize
export def main [name: string] {
    $"hello ($name)!"
}
