# > "let $quiet = false; let $no_timestamp = false" | variables_definitions_to_record
#
# > let multiline_vars = "let $a = 'a'\nlet $b = 'b'\n\n#comment"
# > $multiline_vars | variables_definitions_to_record
export def variables_definitions_to_record []: string -> record {
    str replace -a ";" "\n"
    | str replace -ar '#.*?(\n|$)' ''
    | parse -r 'let (?:\$)*(?<var>.*) = (?s)(?<val>.*?)(?=let|\n\n|$)'
    | compact --empty val # I'm not sure about this rule :\
    | update val {|i| $i.val | str replace -ar "(\n| )+" ' ' | str trim}
    | transpose --ignore-titles --as-record --header-row
}
