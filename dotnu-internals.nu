# make record from variables
#
# > "let $quiet = false; let $no_timestamp = false" | variables_definitions_to_record
# ╭──────────────┬───────╮
# │ quiet        │ false │
# │ no_timestamp │ false │
# ╰──────────────┴───────╯
#
# > "let $a = 'a'\nlet $b = 'b'\n\n#comment" | variables_definitions_to_record
# ╭───┬─────╮
# │ a │ 'a' │
# │ b │ 'b' │
# ╰───┴─────╯
export def variables_definitions_to_record []: string -> record {
    str replace -a ";" "\n"
    | str replace -ar '#.*?(\n|$)' ''
    | parse -r 'let (?:\$)*(?<var>.*) = (?s)(?<val>.*?)(?=let|\n\n|$)'
    | compact --empty val # I'm not sure about this rule :\
    | update val {|i| $i.val | str replace -ar "(\n| )+" ' ' | str trim}
    | transpose --ignore-titles --as-record --header-row
}

export def parse-docstrings [] {
    parse -r "(?:\n\n|^)# (?<desc>.*)\n(?:#\n)(?<examples>(?:(?:\n#)|.)*)\nexport def(?: --(?:env|wrapped))* (?:'|\")?(?<command_name>.*?)(?:'|\")? \\["
}

export def parse-examples [] {
    str replace -ram '^# ?' ''
    | split row "\n\n" # By splitting on groups, we can execute in one command several lines that start with `>`
    | parse -r '(?<annotation>^.+\n)??> (?<command>.+(?:\n\|.+)*)'
}
