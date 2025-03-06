# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

# For a long time, I wanted to be able to update scripts using `dotnu` to capture the output of commands and embed those outputs back into the script. This would make it possible to use version control features for tracking nushell outputs.
# Additionally, I wanted that those scripts could be executed by themselves in bare nushell without any additional modules.
# So far, I have come to the solution that if I want to capture some Nushell output, I just add `| print $in` to the necessary places. Then, I use the command `dotnu embeds-update somescript.nu` to modify the initial script, execute the modified script, substitute the captures inside the script, and save the updated version.
# I wanted this feature many times throughout my nushell history; however, once I implemented it, I forgot about my initial needs and haven't used it in production so far.

ls | sort-by modified -r | last 2 | print $in

# => ╭─#─┬──────name──────┬─type─┬─size──┬───modified───╮
# => │ 0 │ zzz_md_backups │ dir  │ 160 B │ 2 months ago │
# => │ 1 │ test.nu        │ file │  45 B │ 3 months ago │
# => ╰─#─┴──────name──────┴─type─┴─size──┴───modified───╯

random int | print $in

# => 6970240173764648305

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in

# => Say hello to the core team of the Best shell

ls | print $in
# => ╭─#──┬──────────name───────────┬─type─┬──size───┬───modified───╮
# => │ 0  │ LICENSE                 │ file │  1.2 kB │ 2 months ago │
# => │ 1  │ README.md               │ file │ 11.1 kB │ a month ago  │
# => │ 2  │ demo.nu                 │ file │  3.8 kB │ 3 weeks ago  │
# => │ 3  │ dotnu                   │ dir  │   128 B │ now          │
# => │ 4  │ dotnu-capture.nu        │ file │   842 B │ 17 hours ago │
# => │ 5  │ dotnu-embed.demo.nu     │ file │   864 B │ 2 weeks ago  │
# => │ 6  │ dotnu-embeds-capture.nu │ file │   467 B │ 17 hours ago │
# => │ 7  │ media                   │ dir  │    96 B │ a month ago  │
# => │ 8  │ nupm.nuon               │ file │   125 B │ a month ago  │
# => │ 9  │ tests                   │ dir  │   192 B │ a month ago  │
# => │ 10 │ tools.nu                │ file │  3.1 kB │ 2 weeks ago  │
# => │ 11 │ zzz_md_backups          │ dir  │   160 B │ 3 months ago │
# => ╰─#──┴──────────name───────────┴─type─┴──size───┴───modified───╯

ls | print $in
# => ╭─#──┬──────────name───────────┬─type─┬──size───┬────modified────╮
# => │ 0  │ LICENSE                 │ file │  1.2 kB │ 2 months ago   │
# => │ 1  │ README.md               │ file │ 11.1 kB │ a month ago    │
# => │ 2  │ demo.nu                 │ file │  3.8 kB │ 3 weeks ago    │
# => │ 3  │ dotnu                   │ dir  │   128 B │ 25 seconds ago │
# => │ 4  │ dotnu-capture.nu        │ file │  2.1 kB │ now            │
# => │ 5  │ dotnu-embed.demo.nu     │ file │   864 B │ 2 weeks ago    │
# => │ 6  │ dotnu-embeds-capture.nu │ file │   465 B │ now            │
# => │ 7  │ media                   │ dir  │    96 B │ a month ago    │
# => │ 8  │ nupm.nuon               │ file │   125 B │ a month ago    │
# => │ 9  │ tests                   │ dir  │   192 B │ a month ago    │
# => │ 10 │ tools.nu                │ file │  3.1 kB │ 2 weeks ago    │
# => │ 11 │ zzz_md_backups          │ dir  │   160 B │ 3 months ago   │
# => ╰─#──┴──────────name───────────┴─type─┴──size───┴────modified────╯

ls | print $in
# => ╭─#──┬──────────name───────────┬─type─┬──size───┬────modified────╮
# => │ 0  │ LICENSE                 │ file │  1.2 kB │ 2 months ago   │
# => │ 1  │ README.md               │ file │ 11.1 kB │ a month ago    │
# => │ 2  │ demo.nu                 │ file │  3.8 kB │ 3 weeks ago    │
# => │ 3  │ dotnu                   │ dir  │   128 B │ a minute ago   │
# => │ 4  │ dotnu-capture.nu        │ file │  4.1 kB │ now            │
# => │ 5  │ dotnu-embed.demo.nu     │ file │   864 B │ 2 weeks ago    │
# => │ 6  │ dotnu-embeds-capture.nu │ file │   465 B │ 29 seconds ago │
# => │ 7  │ media                   │ dir  │    96 B │ a month ago    │
# => │ 8  │ nupm.nuon               │ file │   125 B │ a month ago    │
# => │ 9  │ tests                   │ dir  │   192 B │ a month ago    │
# => │ 10 │ tools.nu                │ file │  3.1 kB │ 2 weeks ago    │
# => │ 11 │ zzz_md_backups          │ dir  │   160 B │ 3 months ago   │
# => ╰─#──┴──────────name───────────┴─type─┴──size───┴────modified────╯
