#commands
use std iter scan

export def main [
    path: path
] {
    let $97_raw_script = (open ~/cy/cy.nu -r);
    let $98_table = ($97_raw_script | lines | enumerate | rename row_number line | where line =~ '^(export )?def.*\[' | insert command_name {|i| $i.line | str replace -r ' \[.*' '' | split row ' ' | last | str trim -c "'"} )
    let $96_with_index = ($98_table | insert start {|i| $97_raw_script | str index-of $i.line})
    let $95_ast = (nu --ide-ast ~/cy/cy.nu | from json | flatten span)
    let $94_join = ($95_ast | join $96_with_index start -l)
    let $93_scanned = ($94_join | merge ($in.command_name | scan null {|prev curr| if ($curr == null) {$prev} else {$curr} } | wrap command_name | roll up));
    let $92_builtin_commands = (help commands | where command_type in ['builtin' 'keyword'] | get name );
    let $91_not_built_in_commands = ($93_scanned | where shape in [shape_internalcall] | where content not-in $92_builtin_commands);
    let $90_childs_to_merge = ($91_not_built_in_commands | select command_name content | rename parent child | where parent !~ 'test' );
    def 'join-next' [] {join -l $90_childs_to_merge child parent | select parent child_ step | rename parent child | upsert step {|i| $i.step + 1} | where child != null}
    let $89_res = (generate ($90_childs_to_merge | insert step 0) {|i| if not ($i | is-empty) {{out: $i, next: ($i | join-next)}}} | flatten | uniq-by parent child);
    $89_res
}
