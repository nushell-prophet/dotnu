## strange problem with `L`, all are callee
#
#

let $path = '/Users/user/git/nu-goodies/nu-goodies/commands.nu'

dotnu dependencies $path | print $in

#: ╭──#──┬──────────caller──────────┬───────callee────────┬─...─╮
#: │ 0   │ L                        │ bat                 │ ... │
#: │ 1   │ L                        │ less                │ ... │
#: │ 2   │ L                        │ repeat              │ ... │
#: │ 3   │ L                        │ gradient-screen     │ ... │
#: │ 4   │ L                        │ pbpaste             │ ... │
#: │ 5   │ L                        │ pbcopy              │ ... │
#: │ 6   │ L                        │ width-safe          │ ... │
#: │ 7   │ L                        │ wrapit              │ ... │
#: │ 8   │ L                        │ colorit             │ ... │
#: │ 9   │ L                        │ alignit             │ ... │
#: │ 10  │ L                        │ frameit             │ ... │
#: │ 11  │ L                        │ indentit            │ ... │
#: │ 12  │ L                        │ newlineit           │ ... │
#: │ 13  │ L                        │ remove_single_nls   │ ... │
#: │ 14  │ L                        │ str repeat          │ ... │
#: │ 15  │ L                        │ dfr                 │ ... │
#: │ 16  │ L                        │ normalize           │ ... │
#: │ 17  │ L                        │ bar                 │ ... │
#: │ 18  │ L                        │ rand_hex_col2       │ ... │
#: │ 19  │ L                        │ generate_colors     │ ... │
#: │ 20  │ L                        │ check_colors        │ ... │
#: │ 21  │ L                        │ make_hex            │ ... │
#: │ 22  │ L                        │ core_hist           │ ... │
#: │ 23  │ L                        │ pwd                 │ ... │
#: │ 24  │ L                        │ in-vd history       │ ... │
#: │ 25  │ L                        │ gum                 │ ... │
#: │ 26  │ L                        │ code                │ ... │
#: │ 27  │ L                        │ fx                  │ ... │
#: │ 28  │ L                        │ hx                  │ ... │
#: │ 29  │ L                        │ polars              │ ... │
#: │ 30  │ L                        │ has_hier            │ ... │
#: │ 31  │ L                        │ vd                  │ ... │
#: │ 32  │ L                        │ kv set              │ ... │
#: │ 33  │ L                        │ ln                  │ ... │
#: │ 34  │ L                        │ mc                  │ ... │
#: │ 35  │ L                        │ zellij              │ ... │
#: │ 36  │ L                        │ backup-history      │ ... │
#: │ 37  │ L                        │ git                 │ ... │
#: │ 38  │ L                        │ sqlite3             │ ... │
#: │ 39  │ L                        │ gh                  │ ... │
#: │ 40  │ L                        │ cargo               │ ... │
#: │ 41  │ L                        │ tar                 │ ... │
#: │ 42  │ L                        │ number-format       │ ... │
#: │ 43  │ L                        │ significant-digits  │ ... │
#: │ 44  │ L                        │ line                │ ... │
#: │ 45  │ L                        │ hdiutil             │ ... │
#: │ 46  │ L                        │ diskutil            │ ... │
#: │ 47  │ L                        │ now-fn              │ ... │
#: │ 48  │ L                        │ ffmpeg              │ ... │
#: │ 49  │ L                        │ /Users/user/git/whi │ ... │
#: │     │                          │ sper.cpp/transcribe │     │
#: │ 50  │ L                        │ wezterm             │ ... │
#: │ 51  │ L                        │ agg                 │ ... │
#: │ 52  │ L                        │ last-commands       │ ... │
#: │ 53  │ L                        │ to-safe-filename    │ ... │
#: │ 54  │ L                        │ wez-to-ansi         │ ... │
#: │ 55  │ L                        │ freeze              │ ... │
#: │ 56  │ L                        │ fzf                 │ ... │
#: │ 57  │ L                        │ check-clean-working │ ... │
#: │     │                          │ -tree               │     │
#: │ 58  │ nu-complete-macos-apps   │                     │ ... │
#: │ 59  │ O                        │                     │ ... │
#: │ 60  │ bar                      │                     │ ... │
#: │ 61  │ bye                      │                     │ ... │
#: │ 62  │ cb                       │                     │ ... │
#: │ 63  │ center                   │                     │ ... │
#: │ 64  │ copy-cmd                 │                     │ ... │
#: │ 65  │ cprint                   │                     │ ... │
#: │ 66  │ width-safe               │                     │ ... │
#: │ 67  │ wrapit                   │                     │ ... │
#: │ 68  │ remove_single_nls        │                     │ ... │
#: │ 69  │ newlineit                │                     │ ... │
#: │ 70  │ frameit                  │                     │ ... │
#: │ 71  │ colorit                  │                     │ ... │
#: │ 72  │ alignit                  │                     │ ... │
#: │ 73  │ indentit                 │                     │ ... │
#: │ 74  │ nu-complete-colors       │                     │ ... │
#: │ 75  │ dfr enumerate            │                     │ ... │
#: │ 76  │ example                  │                     │ ... │
#: │ 77  │ fill non-exist           │                     │ ... │
#: │ 78  │ format profile           │                     │ ... │
#: │ 79  │ gradient-screen          │                     │ ... │
#: │ 80  │ generate_colors          │                     │ ... │
#: │ 81  │ make_hex                 │                     │ ... │
#: │ 82  │ check_colors             │                     │ ... │
#: │ 83  │ rand_hex_col2            │                     │ ... │
#: │ 84  │ hist                     │                     │ ... │
#: │ 85  │ hs                       │                     │ ... │
#: │ 86  │ in-fx                    │                     │ ... │
#: │ 87  │ in-hx                    │                     │ ... │
#: │ 88  │ in-vd                    │                     │ ... │
#: │ 89  │ in-vd history            │                     │ ... │
#: │ 90  │ has_hier                 │                     │ ... │
#: │ 91  │ ln-for-preview           │                     │ ... │
#: │ 92  │ mc                       │                     │ ... │
#: │ 93  │ md                       │                     │ ... │
#: │ 94  │ mv1                      │                     │ ... │
#: │ 95  │ mygit log                │                     │ ... │
#: │ 96  │ backup-history           │                     │ ... │
#: │ 97  │ normalize                │                     │ ... │
#: │ 98  │ install                  │                     │ ... │
#: │ 99  │ launch                   │                     │ ... │
#: │ 100 │ download-nushell-nightly │                     │ ... │
#: │ 101 │ launch-downloaded        │                     │ ... │
#: │ 102 │ number-col-format        │                     │ ... │
#: │ 103 │ number-format            │                     │ ... │
#: │ 104 │ orbita                   │                     │ ... │
#: │ 105 │ line                     │                     │ ... │
#: │ 106 │ print-and-pass           │                     │ ... │
#: │ 107 │ ramdisk-create           │                     │ ... │
#: │ 108 │ select-i                 │                     │ ... │
#: │ 109 │ side-by-side             │                     │ ... │
#: │ 110 │ significant-digits       │                     │ ... │
#: │ 111 │ str repeat               │                     │ ... │
#: │ 112 │ str append               │                     │ ... │
#: │ 113 │ str prepend              │                     │ ... │
#: │ 114 │ indent                   │                     │ ... │
#: │ 115 │ dedent                   │                     │ ... │
#: │ 116 │ escape-regex             │                     │ ... │
#: │ 117 │ escape-escapes           │                     │ ... │
#: │ 118 │ testcd                   │                     │ ... │
#: │ 119 │ to-safe-filename         │                     │ ... │
#: │ 120 │ to-temp-file             │                     │ ... │
#: │ 121 │ transcribe               │                     │ ... │
#: │ 122 │ wez-to-ansi              │                     │ ... │
#: │ 123 │ wez-to-gif               │                     │ ... │
#: │ 124 │ wez-to-png               │                     │ ... │
#: │ 125 │ now-fn                   │                     │ ... │
#: │ 126 │ last-commands            │                     │ ... │
#: │ 127 │ z                        │                     │ ... │
#: │ 128 │ replace-in-all-files     │                     │ ... │
#: │ 129 │ check-clean-working-tree │                     │ ... │
#: ╰──#──┴──────────caller──────────┴───────callee────────┴─...─╯
