mut $prev_ts = date now
print "> [1;36msleep[0m [1;35m0.5[0m[32msec[0m"
sleep 0.5sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);


print "> [1;36msleep[0m [1;35m0.7[0m[32msec[0m"
sleep 0.7sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);


print "> [1;36msleep[0m [1;35m0.8[0m[32msec[0m"
sleep 0.8sec
print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);

