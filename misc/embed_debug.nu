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
print $"   Length: ($orig_src | str length)"
print $"   Hex (first 200): ($orig_src | encode hex | str substring 0..200)"
print ""

# Step 2: Apply the same replacements as execute-and-parse-results
print "2. Applying str replace operations..."

let src1 = $orig_src | 'def embed-in-script [] ' + $in
print $"   After prepending 'def': length ($src1 | str length)"

let marker_open = (capture-marker)
let marker_close = (capture-marker --close)
print $"   Marker open: ($marker_open | encode hex)"
print $"   Marker close: ($marker_close | encode hex)"

let src2 = $src1 | str replace 'capture-marker' $"'($marker_open)'"
print $"   After replacing 'capture-marker': length ($src2 | str length)"
let contains_marker = ($src2 | str contains ($marker_open))
print $"   Contains marker in source: ($contains_marker)"

let src3 = $src2 | str replace '(capture-marker --close)' $"'($marker_close)'"
print $"   After replacing '(capture-marker --close)': length ($src3 | str length)"

let src4 = $src3 | str replace 'comment-hash-colon' (comment-hash-colon --source-code)
print $"   After replacing 'comment-hash-colon': length ($src4 | str length)"

let src5 = $src4 | str replace 'to text' "str join \"\\n\""
print $"   After replacing 'to text': length ($src5 | str length)"
print ""

print "3. Final embed-in-script source:"
print $src5
print ""
print $"   Hex: ($src5 | encode hex)"
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
print $"   Raw output length: ($raw_output | str length)"
print $"   Raw output hex: ($raw_output | encode hex)"
print ""

# Step 5: Try to parse
print "6. Parsing output..."
let regex = '(?s)' + $marker_open + '(.*?)' + $marker_close
print $"   Regex pattern hex: ($regex | encode hex)"

let parsed = ($raw_output | ansi strip | parse -r $regex)
print $"   Parsed results: ($parsed | length) captures"
if ($parsed | is-not-empty) {
    print $"   First capture: ($parsed | get capture0 | first)"
}
print ""

print "=== END EMBED DEBUG ==="
