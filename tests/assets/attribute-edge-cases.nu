# Test file for attribute decorator edge cases

# Multi-word attribute with closure - calls inside should be excluded
@example 'demo' {
    email-formatter  # this call should NOT appear in dependencies
}
export def 'decorated-command' [] {
    email-formatter  # this call SHOULD appear
}

# This command has @something in a string - should NOT be treated as attribute
export def 'email-formatter' [] {
    let template = "Contact us @support or @help for assistance"
    $template | str replace '@support' 'support@example.com'
}

# Raw string with @fake at line start - should NOT be treated as attribute
export def 'raw-string-command' [] {
    r###'
@fake is a fabricated raw string
'###
    email-formatter  # this call SHOULD appear
}

# Regular command for dependency testing
export def 'main-command' [] {
    email-formatter
}

# Raw string with @example 'text' that MATCHES attribute regex - should NOT be treated as attribute
# This is the tricky case: the line looks exactly like a real attribute decorator
export def 'tricky-raw-string-command' [] {
    r###'
@example 'this line matches attribute regex but is inside raw string!'
'###
    email-formatter  # this call SHOULD appear - bug if it doesn't!
}
