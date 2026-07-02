export def countdown [n: int] {
    if $n > 0 { countdown ($n - 1) }
}
