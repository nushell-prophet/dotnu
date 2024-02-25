# create a file that will print and execute all the commands by blocks.
# Blocks are made by empty lines between commands.
export def main [
    file: path # path to `.nu` file
] {
    let $out_file = ($file + 'setx.nu')

    open $file
    | str trim --char (char nl)
    | split row -r "\n+\n"
    | each {|block|
        ($"print `> ($block | str replace -ar '([^\\]?)"' '$1\"' | nu-highlight)`\n($block)"
        + "\nprint $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);\n\n")
    }
    | prepend 'mut $prev_ts = (date now)'
    | save -f $out_file
    

    print $'the file ($out_file) is produced. Source it'

    commandline $'source ($out_file)'
}
