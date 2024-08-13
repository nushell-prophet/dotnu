use mod.nu hi

export def main [] {
    (hi Amtoine) == 'hi Amtoine!'
    | if not $in {
        print 'there is an error here' # I don't use `std assert` here to simplify example commands output
    }
}
