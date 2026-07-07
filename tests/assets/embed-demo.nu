let $a = ls ~

$a | print $in

# Not `ls ~/temp` because: that path only exists on the author's machine
let $b = ls .

$b | print $in
