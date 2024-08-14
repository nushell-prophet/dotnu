clear; "dotnu dependencies" |  figlet -f 'phm-rounded.flf' -C utf8 | lines | where $it !~ '^\s*$' | table

# Let's use a simple example module
ls tests/assets/module-say/say/

# Let's check what is the content of it's files
glob tests/assets/module-say/say/*.nu | sort | each {|i| $i | open | lines | where $it !~ '^#' | print $i $in }

# Let's examine which commands of the module depends on which commands.
# We pass the files to examine using glob expansion
dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)

# Let's find which commands have no tests
dotnu dependencies ...(glob tests/assets/module-say/say/*.nu)
| dotnu filter-commands-with-no-tests

clear; "dotnu parse-docstrings" |  figlet -f 'phm-rounded.flf' -C utf8 | lines | where $it !~ '^\s*$' | table

# Let's check an example module file
open tests/assets/module-say/say/hello.nu

# Let's use `dotnu parse-docstrings` with this file
dotnu parse-docstrings tests/assets/module-say/say/hello.nu | reject input | get 0 | table -e

clear; "dotnu update-docstring-examples" |  figlet -f 'phm-rounded.flf' -C utf8 | lines | where $it !~ '^\s*$' | table

# Let's change some example for demonstration
code -n tests/assets/module-say/say/hello.nu

# Let's apply the command
dotnu update-docstring-examples tests/assets/module-say/say/hello.nu

# Let's see the results
code tests/assets/module-say/say/hello.nu

clear; "generate-nupm-tests" |  figlet -f 'phm-rounded.flf' -C utf8 | lines | where $it !~ '^\s*$' | table

# to demonstrate another command let's apply already familiar to us `dotnu dependencies`
# to its own module files
dotnu dependencies dotnu/mod.nu dotnu/dotnu-internals.nu tools.nu ...(glob tests/*.nu)

# let's see that in mod.nu file we have 4 commands with no tests now
dotnu dependencies dotnu/mod.nu dotnu/dotnu-internals.nu tools.nu ...(glob tests/*.nu)
| dotnu filter-commands-with-no-tests

# let's parse the file to see that we have some examples there
dotnu parse-docstrings dotnu/mod.nu | where results != []

# and as an example of use the structured output from `parse docstrings`
# let's use another command
dotnu generate-nupm-tests dotnu/mod.nu

# let's see what new files we have
lg

# let's run `nupm test`
use /Users/user/git/nupm/nupm; nupm test

# let's see that the number of commands with no tests is smaller now
dotnu dependencies dotnu/mod.nu dotnu/dotnu-internals.nu tools.nu ...(glob tests/*.nu)
| dotnu filter-commands-with-no-tests
