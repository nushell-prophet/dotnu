# this is a typical nushell script

ls | sort-by modified -r | last 2 | print $in

#: ╭─#─┬───────name───────┬─type─┬──size──┬────modified────╮
#: │ 0 │ dotnu-capture.nu │ file │  201 B │ 15 seconds ago │
#: │ 1 │ demo.nu          │ file │ 3.8 kB │ 7 minutes ago  │
#: ╰─#─┴───────name───────┴─type─┴──size──┴────modified────╯

random int | print $in

#: 3515821150955196512

'Say hello to the core team of the Nushell' | str replace 'Nushell' 'Best shell' | print $in

#: Say hello to the core team of the Best shell
