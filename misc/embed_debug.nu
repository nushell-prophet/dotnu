# Debug script to trace exactly what execute-and-parse-results does
# Run from dotnu root: nu misc/embed_debug.nu

use ../dotnu/commands.nu *

print "=== EMBED DEBUG ==="
print ""

# Step 1: Define the same closure as execute-and-parse-results
let embed_in_script = {
    let input = table -e
    | comment-hash-colon

    capture-marker
    | append $input
    | append (capture-marker --close)
    | to text
    | print
}

print "1. Original closure source:"
let orig_src = (view source $embed_in_script)
let orig_len = ($orig_src | str length)
let orig_hex = ($orig_src | encode hex | str substring 0..200)
print $"   Length: ($orig_len)"
print $"   Hex \(first 200\): ($orig_hex)"
print ""

# Step 2: Apply the same replacements as execute-and-parse-results
print "2. Applying str replace operations..."

let src1 = $orig_src | 'def embed-in-script [] ' + $in
let src1_len = ($src1 | str length)
print $"   After prepending 'def': length ($src1_len)"

let marker_open = (capture-marker)
let marker_close = (capture-marker --close)
let marker_open_hex = ($marker_open | encode hex)
let marker_close_hex = ($marker_close | encode hex)
print $"   Marker open: ($marker_open_hex)"
print $"   Marker close: ($marker_close_hex)"

let src2 = $src1 | str replace 'capture-marker' $"'($marker_open)'"
let src2_len = ($src2 | str length)
let contains_marker = ($src2 | str contains $marker_open)
print $"   After replacing 'capture-marker': length ($src2_len)"
print $"   Contains marker in source: ($contains_marker)"

let src3 = $src2 | str replace '(capture-marker --close)' $"'($marker_close)'"
let src3_len = ($src3 | str length)
print $"   After replacing '\(capture-marker --close\)': length ($src3_len)"

let src4 = $src3 | str replace 'comment-hash-colon' (comment-hash-colon --source-code)
let src4_len = ($src4 | str length)
print $"   After replacing 'comment-hash-colon': length ($src4_len)"

let src5 = $src4 | str replace 'to text' "str join \"\\n\""
let src5_len = ($src5 | str length)
print $"   After replacing 'to text': length ($src5_len)"
print ""

print "3. Final embed-in-script source:"
print $src5
print ""
let src5_hex = ($src5 | encode hex)
print $"   Hex: ($src5_hex)"
print ""

# Step 3: Build a test script like execute-and-parse-results does
print "4. Building test script..."
let test_script = "'hello world' | print $in"

let script_updated = $test_script
| lines
| each {
    if $in !~ '^\s*#' {
        str replace -r '\| *print +\$in *' '| embed-in-script'
    } else { }
}
| prepend $src5
| str join "\n"

print "   Script to execute:"
print $script_updated
print ""

# Step 4: Execute and capture
print "5. Executing subprocess..."
let raw_output = (^$nu.current-exe -n -c $script_updated)
let raw_len = ($raw_output | str length)
let raw_hex = ($raw_output | encode hex)
print $"   Raw output length: ($raw_len)"
print $"   Raw output hex: ($raw_hex)"
print ""

# Step 5: Try to parse
print "6. Parsing output..."
let regex = '(?s)' + $marker_open + '(.*?)' + $marker_close
let regex_hex = ($regex | encode hex)
print $"   Regex pattern hex: ($regex_hex)"

let stripped = ($raw_output | ansi strip)
let parsed = ($stripped | parse -r $regex)
let parsed_len = ($parsed | length)
print $"   Parsed results: ($parsed_len) captures"
if ($parsed | is-not-empty) {
    let first_cap = ($parsed | get capture0 | first)
    print $"   First capture: ($first_cap)"
}
print ""

print "=== END EMBED DEBUG ==="
