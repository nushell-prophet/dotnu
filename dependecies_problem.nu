## strange problem with `L`, all are callee
#
#

let $path = '/Users/user/git/nu-goodies/nu-goodies/commands.nu'

dotnu dependencies $path | print $in

#: ╭────#─────┬────────────caller─────────────┬───────────────────callee────────────────────┬───filename_of_caller────┬───step───╮
#: │ 0        │ L                             │ bat                                         │ commands.nu             │        0 │
#: │ 1        │ L                             │ less                                        │ commands.nu             │        0 │
#: │ 2        │ L                             │ repeat                                      │ commands.nu             │        0 │
#: │ 3        │ L                             │ gradient-screen                             │ commands.nu             │        0 │
#: │ 4        │ L                             │ pbpaste                                     │ commands.nu             │        0 │
#: │ 5        │ L                             │ pbcopy                                      │ commands.nu             │        0 │
#: │ 6        │ L                             │ width-safe                                  │ commands.nu             │        0 │
#: │ 7        │ L                             │ wrapit                                      │ commands.nu             │        0 │
#: │ 8        │ L                             │ colorit                                     │ commands.nu             │        0 │
#: │ 9        │ L                             │ alignit                                     │ commands.nu             │        0 │
#: │ 10       │ L                             │ frameit                                     │ commands.nu             │        0 │
#: │ 11       │ L                             │ indentit                                    │ commands.nu             │        0 │
#: │ 12       │ L                             │ newlineit                                   │ commands.nu             │        0 │
#: │ 13       │ L                             │ remove_single_nls                           │ commands.nu             │        0 │
#: │ 14       │ L                             │ str repeat                                  │ commands.nu             │        0 │
#: │ 15       │ L                             │ dfr                                         │ commands.nu             │        0 │
#: │ 16       │ L                             │ normalize                                   │ commands.nu             │        0 │
#: │ 17       │ L                             │ bar                                         │ commands.nu             │        0 │
#: │ 18       │ L                             │ rand_hex_col2                               │ commands.nu             │        0 │
#: │ 19       │ L                             │ generate_colors                             │ commands.nu             │        0 │
#: │ 20       │ L                             │ check_colors                                │ commands.nu             │        0 │
#: │ 21       │ L                             │ make_hex                                    │ commands.nu             │        0 │
#: │ 22       │ L                             │ core_hist                                   │ commands.nu             │        0 │
#: │ 23       │ L                             │ pwd                                         │ commands.nu             │        0 │
#: │ 24       │ L                             │ in-vd history                               │ commands.nu             │        0 │
#: │ 25       │ L                             │ gum                                         │ commands.nu             │        0 │
#: │ 26       │ L                             │ code                                        │ commands.nu             │        0 │
#: │ 27       │ L                             │ fx                                          │ commands.nu             │        0 │
#: │ 28       │ L                             │ hx                                          │ commands.nu             │        0 │
#: │ 29       │ L                             │ polars                                      │ commands.nu             │        0 │
#: │ 30       │ L                             │ has_hier                                    │ commands.nu             │        0 │
#: │ 31       │ L                             │ vd                                          │ commands.nu             │        0 │
#: │ 32       │ L                             │ kv set                                      │ commands.nu             │        0 │
#: │ 33       │ L                             │ ln                                          │ commands.nu             │        0 │
#: │ 34       │ L                             │ mc                                          │ commands.nu             │        0 │
#: │ 35       │ L                             │ zellij                                      │ commands.nu             │        0 │
#: │ 36       │ L                             │ backup-history                              │ commands.nu             │        0 │
#: │ 37       │ L                             │ git                                         │ commands.nu             │        0 │
#: │ 38       │ L                             │ sqlite3                                     │ commands.nu             │        0 │
#: │ 39       │ L                             │ gh                                          │ commands.nu             │        0 │
#: │ 40       │ L                             │ cargo                                       │ commands.nu             │        0 │
#: │ 41       │ L                             │ tar                                         │ commands.nu             │        0 │
#: │ 42       │ L                             │ number-format                               │ commands.nu             │        0 │
#: │ 43       │ L                             │ significant-digits                          │ commands.nu             │        0 │
#: │ 44       │ L                             │ line                                        │ commands.nu             │        0 │
#: │ 45       │ L                             │ hdiutil                                     │ commands.nu             │        0 │
#: │ 46       │ L                             │ diskutil                                    │ commands.nu             │        0 │
#: │ 47       │ L                             │ now-fn                                      │ commands.nu             │        0 │
#: │ 48       │ L                             │ ffmpeg                                      │ commands.nu             │        0 │
#: │ 49       │ L                             │ /Users/user/git/whisper.cpp/transcribe      │ commands.nu             │        0 │
#: │ 50       │ L                             │ wezterm                                     │ commands.nu             │        0 │
#: │ 51       │ L                             │ agg                                         │ commands.nu             │        0 │
#: │ 52       │ L                             │ last-commands                               │ commands.nu             │        0 │
#: │ 53       │ L                             │ to-safe-filename                            │ commands.nu             │        0 │
#: │ 54       │ L                             │ wez-to-ansi                                 │ commands.nu             │        0 │
#: │ 55       │ L                             │ freeze                                      │ commands.nu             │        0 │
#: │ 56       │ L                             │ fzf                                         │ commands.nu             │        0 │
#: │ 57       │ L                             │ check-clean-working-tree                    │ commands.nu             │        0 │
#: │ 58       │ nu-complete-macos-apps        │                                             │ commands.nu             │        0 │
#: │ 59       │ O                             │                                             │ commands.nu             │        0 │
#: │ 60       │ bar                           │                                             │ commands.nu             │        0 │
#: │ 61       │ bye                           │                                             │ commands.nu             │        0 │
#: │ 62       │ cb                            │                                             │ commands.nu             │        0 │
#: │ 63       │ center                        │                                             │ commands.nu             │        0 │
#: │ 64       │ copy-cmd                      │                                             │ commands.nu             │        0 │
#: │ 65       │ cprint                        │                                             │ commands.nu             │        0 │
#: │ 66       │ width-safe                    │                                             │ commands.nu             │        0 │
#: │ 67       │ wrapit                        │                                             │ commands.nu             │        0 │
#: │ 68       │ remove_single_nls             │                                             │ commands.nu             │        0 │
#: │ 69       │ newlineit                     │                                             │ commands.nu             │        0 │
#: │ 70       │ frameit                       │                                             │ commands.nu             │        0 │
#: │ 71       │ colorit                       │                                             │ commands.nu             │        0 │
#: │ 72       │ alignit                       │                                             │ commands.nu             │        0 │
#: │ 73       │ indentit                      │                                             │ commands.nu             │        0 │
#: │ 74       │ nu-complete-colors            │                                             │ commands.nu             │        0 │
#: │ 75       │ dfr enumerate                 │                                             │ commands.nu             │        0 │
#: │ 76       │ example                       │                                             │ commands.nu             │        0 │
#: │ 77       │ fill non-exist                │                                             │ commands.nu             │        0 │
#: │ 78       │ format profile                │                                             │ commands.nu             │        0 │
#: │ 79       │ gradient-screen               │                                             │ commands.nu             │        0 │
#: │ 80       │ generate_colors               │                                             │ commands.nu             │        0 │
#: │ 81       │ make_hex                      │                                             │ commands.nu             │        0 │
#: │ 82       │ check_colors                  │                                             │ commands.nu             │        0 │
#: │ 83       │ rand_hex_col2                 │                                             │ commands.nu             │        0 │
#: │ 84       │ hist                          │                                             │ commands.nu             │        0 │
#: │ 85       │ hs                            │                                             │ commands.nu             │        0 │
#: │ 86       │ in-fx                         │                                             │ commands.nu             │        0 │
#: │ 87       │ in-hx                         │                                             │ commands.nu             │        0 │
#: │ 88       │ in-vd                         │                                             │ commands.nu             │        0 │
#: │ 89       │ in-vd history                 │                                             │ commands.nu             │        0 │
#: │ 90       │ has_hier                      │                                             │ commands.nu             │        0 │
#: │ 91       │ ln-for-preview                │                                             │ commands.nu             │        0 │
#: │ 92       │ mc                            │                                             │ commands.nu             │        0 │
#: │ 93       │ md                            │                                             │ commands.nu             │        0 │
#: │ 94       │ mv1                           │                                             │ commands.nu             │        0 │
#: │ 95       │ mygit log                     │                                             │ commands.nu             │        0 │
#: │ 96       │ backup-history                │                                             │ commands.nu             │        0 │
#: │ 97       │ normalize                     │                                             │ commands.nu             │        0 │
#: │ 98       │ install                       │                                             │ commands.nu             │        0 │
#: │ 99       │ launch                        │                                             │ commands.nu             │        0 │
#: │ 100      │ download-nushell-nightly      │                                             │ commands.nu             │        0 │
#: │ 101      │ launch-downloaded             │                                             │ commands.nu             │        0 │
#: │ 102      │ number-col-format             │                                             │ commands.nu             │        0 │
#: │ 103      │ number-format                 │                                             │ commands.nu             │        0 │
#: │ 104      │ orbita                        │                                             │ commands.nu             │        0 │
#: │ 105      │ line                          │                                             │ commands.nu             │        0 │
#: │ 106      │ print-and-pass                │                                             │ commands.nu             │        0 │
#: │ 107      │ ramdisk-create                │                                             │ commands.nu             │        0 │
#: │ 108      │ select-i                      │                                             │ commands.nu             │        0 │
#: │ 109      │ side-by-side                  │                                             │ commands.nu             │        0 │
#: │ 110      │ significant-digits            │                                             │ commands.nu             │        0 │
#: │ 111      │ str repeat                    │                                             │ commands.nu             │        0 │
#: │ 112      │ str append                    │                                             │ commands.nu             │        0 │
#: │ 113      │ str prepend                   │                                             │ commands.nu             │        0 │
#: │ 114      │ indent                        │                                             │ commands.nu             │        0 │
#: │ 115      │ dedent                        │                                             │ commands.nu             │        0 │
#: │ 116      │ escape-regex                  │                                             │ commands.nu             │        0 │
#: │ 117      │ escape-escapes                │                                             │ commands.nu             │        0 │
#: │ 118      │ testcd                        │                                             │ commands.nu             │        0 │
#: │ 119      │ to-safe-filename              │                                             │ commands.nu             │        0 │
#: │ 120      │ to-temp-file                  │                                             │ commands.nu             │        0 │
#: │ 121      │ transcribe                    │                                             │ commands.nu             │        0 │
#: │ 122      │ wez-to-ansi                   │                                             │ commands.nu             │        0 │
#: │ 123      │ wez-to-gif                    │                                             │ commands.nu             │        0 │
#: │ 124      │ wez-to-png                    │                                             │ commands.nu             │        0 │
#: │ 125      │ now-fn                        │                                             │ commands.nu             │        0 │
#: │ 126      │ last-commands                 │                                             │ commands.nu             │        0 │
#: │ 127      │ z                             │                                             │ commands.nu             │        0 │
#: │ 128      │ replace-in-all-files          │                                             │ commands.nu             │        0 │
#: │ 129      │ check-clean-working-tree      │                                             │ commands.nu             │        0 │
#: ╰────#─────┴────────────caller─────────────┴───────────────────callee────────────────────┴───filename_of_caller────┴───step───╯
