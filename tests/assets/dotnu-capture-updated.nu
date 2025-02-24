# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

ls | sort-by modified -r | last 2 | print $in

#: ╭─#─┬──────name──────┬─type─┬──size──┬───modified───╮
#: │ 0 │ LICENSE        │ file │ 1.2 kB │ 2 months ago │
#: │ 1 │ zzz_md_backups │ dir  │  160 B │ 3 months ago │
#: ╰─#─┴──────name──────┴─type─┴──size──┴───modified───╯

random int | print $in

#: 8077574741879556293

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in

#: Say hello to the core team of the Best shell
