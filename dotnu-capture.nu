# this is a typical nushell script

ls | sort-by modified -r | first 2 | print $in

random int | print $in

'Say hello to the core team of the Nushell' | str replace 'Nushell' 'Best shell' | print $in
