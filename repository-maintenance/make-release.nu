let $git_info = (gh repo view --json description,name | from json);
let $git_tag = (git tag | lines | prepend '0.0.0' | sort -n | last | inc -p)
let $desc = ($git_info | get description)

open nupm.nuon
| update description ($desc | str replace -r $'^($git_info.name) - ' '')
| update version $git_tag
| save -f nupm.nuon

'README.md'
| if ($in | path exists) {
    open -r
} else {"\n"}
| lines
| update 0 ('<h1 align="center">' + $git_info.name + '<br>' + $desc + '</h1>')
| str join (char nl)
| $in + (char nl)
| save -f README.md

prettier README.md -w

use nupm
nupm install --force --path .

git add nupm.nuon
git commit -m $'($git_tag) nupm version'
git tag $git_tag
