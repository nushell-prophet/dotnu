# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

ls | sort-by modified -r | last 2 | print $in

#: ╭─#─┬─────────────name─────────────┬─type─┬─size──┬─modified─╮
#: │ 0 │ set-x-demo.nu                │ file │  41 B │ 6 months │
#: │   │                              │      │       │  ago     │
#: │ 1 │ parsing-pipe-in-docstring.nu │ file │ 923 B │ 6 months │
#: │   │                              │      │       │  ago     │
#: ╰─#─┴─────────────name─────────────┴─type─┴─size──┴─modified─╯

random int | print $in

#: 2748753383717072377

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in

#: Say hello to the core team of the Best shell
