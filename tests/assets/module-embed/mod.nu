use helpers.nu greet-word
export use pub.nu *

export def main [] { greet }

export def greet [] { $"(greet-word) (subject)!" }

def subject [] { 'world' }
