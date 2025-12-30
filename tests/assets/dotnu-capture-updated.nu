# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

ls | sort-by modified -r | last 2 | print $in
# => ╭───┬──────────────────────────────┬──────┬───────┬────────────╮
# => │ # │             name             │ type │ size  │  modified  │
# => ├───┼──────────────────────────────┼──────┼───────┼────────────┤
# => │ 0 │ set-x-demo.nu                │ file │  41 B │ a year ago │
# => │ 1 │ parsing-pipe-in-docstring.nu │ file │ 923 B │ a year ago │
# => ╰───┴──────────────────────────────┴──────┴───────┴────────────╯

random int | print $in
# => 5037388629847034664

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in
# => Say hello to the core team of the Best shell
