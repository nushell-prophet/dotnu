# Windows debugging script for dotnu CRLF issues
# Run with: nu misc/windows_debug.nu

print "=== DOTNU WINDOWS DEBUG ==="
print ""

print "1. System info:"
print $"   OS: (sys host | get name)"
print $"   Nu version: (version | get version)"
print ""

print "2. Line ending test (expect 0A on Unix, 0D0A on Windows):"
let line_hex = (nu -c "'line1\nline2' | to text" | encode hex | str substring 0..30)
print $"   to text hex: ($line_hex)"
print ""

print "3. Subprocess output test:"
let sub_out = (nu -c "'hello from subprocess'")
print $"   Output: ($sub_out)"
print $"   Hex: ($sub_out | encode hex)"
print ""

print "4. Capture marker test:"
let marker_open = "<<<DOTNU-EMBED-CAPTURE>>>"
let marker_close = "<<<DOTNU-EMBED-CAPTURE>>><<<END>>>"
let test_str = $"before\n($marker_open)\ncaptured content\n($marker_close)\nafter"
print $"   Test string created"
let parsed = ($test_str | parse -r '(?s)<<<DOTNU-EMBED-CAPTURE>>>\(.*?\)<<<DOTNU-EMBED-CAPTURE>>><<<END>>>')
print $"   Parsed result: ($parsed)"
print ""

print "5. Actual capture-marker values from dotnu:"
use ../dotnu/commands.nu *
let real_open = (capture-marker)
let real_close = (capture-marker --close)
print $"   Open marker hex: ($real_open | encode hex)"
print $"   Close marker hex: ($real_close | encode hex)"
print $"   Expected: E2808BE2808C (ZWSP+ZWNJ) and E2808CE2808B (ZWNJ+ZWSP)"
print ""

print "5b. Zero-width chars through subprocess:"
let sub_marker = (nu -c "print '\\u{200B}\\u{200C}'")
print $"   Subprocess marker hex: ($sub_marker | encode hex)"
print ""

print "5c. Real capture-marker through subprocess:"
let real_script = $"
use dotnu/commands.nu [capture-marker]
let open = \(capture-marker\)
let close = \(capture-marker --close\)
print \($open + 'CAPTURED' + $close\)
"
let real_result = (nu -c $real_script | complete)
print $"   Stdout hex: ($real_result.stdout | encode hex)"
let real_parsed = ($real_result.stdout | parse -r $'(?s)($real_open)(.*?)($real_close)')
print $"   Parsed with real markers: ($real_parsed | length) captures"
print ""

print "6. Simulated embed capture (like execute-and-parse-results):"
let script = "
def embed-in-script [] {
    let input = $in | table -e
    '<<<DOTNU>>>'
    | append $input
    | append '<<<DOTNU>>><<<END>>>'
    | str join \"\\n\"
    | print
}
'test data' | embed-in-script
"
print "   Running subprocess with embed script..."
let result = (nu -c $script | complete)
print $"   Exit code: ($result.exit_code)"
print $"   Stdout length: ($result.stdout | str length)"
print $"   Stdout hex : ($result.stdout | encode hex | str substring 0..100)"
print ""

print "7. Parse the subprocess output:"
let parsed2 = ($result.stdout | parse -r '(?s)<<<DOTNU>>>(.*?)<<<DOTNU>>><<<END>>>')
print $"   Parsed captures: ($parsed2 | length)"
if ($parsed2 | is-not-empty) {
    print $"   First capture: ($parsed2 | get 0)"
}
print ""

print "8. Test str join with explicit newline:"
let joined = (["a" "b" "c"] | str join "\n")
print $"   Joined hex: ($joined | encode hex)"
print ""

print "=== END DEBUG ==="
