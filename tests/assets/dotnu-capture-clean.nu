# open ([tests assets dotnu-capture.nu] | path join)
# | dotnu embeds-remove
# this is a typical nushell script
# embeds in this script can be updated using command:
# `dotnu embeds-update dotnu-capture.nu`
#
# And and this is the link on dotnu module:
# https://github.com/nushell-prophet/dotnu

ls | sort-by modified -r | last 2 | print $in

random int | print $in

'Say hello to the core team of the Nushell'
| str replace 'Nushell' 'Best shell'
| print $in
