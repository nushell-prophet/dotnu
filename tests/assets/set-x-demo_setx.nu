mut $prev_ts = date now
print ("> sleep 0.5sec" | nu-highlight)
sleep 0.5sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);


print ("> sleep 0.7sec" | nu-highlight)
sleep 0.7sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);


print ("> sleep 0.8sec" | nu-highlight)
sleep 0.8sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);
