#commands
use std iter scan

# Check .nu module file for which commands use other commands
export def main [
    path: path # path to a .nu module file.
    --keep_builtins # keep builtin commands in the result page
] {
    let $97_raw_script = (open $path -r);
    let $98_table = ($97_raw_script | lines | enumerate | rename row_number line | where line =~ '^(export )?def.*\[' | insert command_name {|i| $i.line | str replace -r ' \[.*' '' | split row ' ' | last | str trim -c "'"} )
    let $96_with_index = ($98_table | insert start {|i| $97_raw_script | str index-of $i.line})
    let $95_ast = (nu --ide-ast $path | from json | flatten span)
    let $94_join = ($95_ast | join $96_with_index start -l)
    let $93_scanned = ($94_join | merge ($in.command_name | scan null {|prev curr| if ($curr == null) {$prev} else {$curr} } | wrap command_name | roll up));

    let $91_not_built_in_commands = (
        $93_scanned
        | where shape in [shape_internalcall]
        | if $keep_builtins {} else {
            where content not-in (
                help commands | where command_type in ['builtin' 'keyword'] | get name
            )
        }
    );
    let $90_childs_to_merge = ($91_not_built_in_commands | select command_name content | rename parent child | where parent != null);

    def 'join-next' [] {join -l $90_childs_to_merge child parent | select parent child_ step | rename parent child | upsert step {|i| $i.step + 1} | where child != null}

    let $89_res = (generate ($90_childs_to_merge | insert step 0) {|i| if not ($i | is-empty) {{out: $i, next: ($i | join-next)}}} | flatten | uniq-by parent child);
    $89_res
}
