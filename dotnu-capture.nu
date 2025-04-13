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
