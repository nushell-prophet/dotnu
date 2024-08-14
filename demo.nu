$env.PROMPT_COMMAND = {|| "\n> "}
clear; 'dotnu' |  figlet -f 'phm-rounded.flf' -C utf8 | lines | where $it !~ '^\s*$'
| fill -a center --width ((term size).columns - 5) | table --index false | ansi strip
| ((ansi green_bold) + $in + (ansi reset)  + (char nl) +
    (ansi grey) + ('https://github.com/nushell-prophet/dotnu' | fill -a center --width ((term size).columns - 5)) +
    (ansi reset ) + "\n\n\n") | print;

"dotnu dependencies" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false

# Let's use a simple example module
ls tests/assets/module-say/say/

# Let's check what the content of its files is
glob tests/assets/module-say/say/*.nu | sort
| each {|i| $i | open | lines | where $it !~ '^#' | print $i $in }

# Let's examine which commands of the module depend on which commands.
# We pass the files to examine using glob expansion
dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)

# Let's find which commands have no tests
dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
| dotnu filter-commands-with-no-tests

clear; "dotnu parse-docstrings" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false

# Let's check an example module file
open tests/assets/module-say/say/hello.nu | nu-highlight

# Let's use `dotnu parse-docstrings` with this file
dotnu parse-docstrings tests/assets/module-say/say/hello.nu | reject input | get 0 | table -e

clear; "dotnu update-docstring-examples" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false

# Let's change some examples for demonstration
code tests/assets/module-say/say/hello.nu

# Let's apply the command
dotnu update-docstring-examples tests/assets/module-say/say/hello.nu

# Let's see the results
code tests/assets/module-say/say/hello.nu

clear; "dotnu generate-nupm-tests" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false

# To demonstrate another command, let's apply the already familiar `dotnu dependencies`
# to its own module files
dotnu dependencies dotnu/mod.nu ...(glob tests/*.nu)

# Let's see that in the mod.nu file we have 4 commands with no tests now
dotnu dependencies dotnu/mod.nu ...(glob tests/*.nu)
| dotnu filter-commands-with-no-tests

# Let's parse the file to see that we have some examples there
code -g dotnu/mod.nu:173;
dotnu parse-docstrings dotnu/mod.nu | where command_name == set-x | reject input | get 0 | table -e

# As an example of using the structured output from `parse docstrings`
# let's use another command
dotnu generate-nupm-tests dotnu/mod.nu

# Let's see what new files we have
lazygit

# Let's run `nupm test`
use /Users/user/git/nupm/nupm; nupm test

# Let's see that the number of commands with no tests is smaller now
dotnu dependencies dotnu/mod.nu ...(glob tests/*.nu)
| dotnu filter-commands-with-no-tests

clear; "dotnu set-x" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false

# Let's examine a simple .nu script
open tests/assets/set-x-demo.nu

# Let's apply `dotnu set-x`
dotnu set-x tests/assets/set-x-demo.nu

# Let's see the content of a produced file
open /Users/user/git/dotnu/tests/assets/set-x-demo_setx.nu

clear; "thanks for watching!" | str upcase | figlet -w 140 -f 'phm-largetype.flf' -C utf8 | lines | fill -a center --width ((term size).columns - 5) | table --index false
