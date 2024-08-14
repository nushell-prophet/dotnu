use mod.nu hi

export def main [] {
    (hi Amtoine) == 'hi Amtoine!'
    | if not $in {
        print 'there is an error here'
    }
}
