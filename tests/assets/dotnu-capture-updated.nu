# dotnu embeds-update ([tests assets dotnu-capture.nu] | path join) --echo
# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

40 + 2 | print $in
# => 42

[[name type]; [foo file] [bar dir]] | print $in
# => ╭───┬──────┬──────╮
# => │ # │ name │ type │
# => ├───┼──────┼──────┤
# => │ 0 │ foo  │ file │
# => │ 1 │ bar  │ dir  │
# => ╰───┴──────┴──────╯

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in
# => Say hello to the core team of the Best shell
