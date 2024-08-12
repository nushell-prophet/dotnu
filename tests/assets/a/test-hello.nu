use hello.nu

export def main [] {
    (hello Amtoine) == 'hello Amtoine!'
    | if not $in {
        print 'there is an error here' # I don't use `std assert` here to simplify example commands output
    }
}
