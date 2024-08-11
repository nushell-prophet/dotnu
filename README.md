
![dotnu](https://github.com/user-attachments/assets/7bbf0ec3-6ac7-45db-8b00-cc11e18e6dc4)

# dotnu - generate scripts from `.nu` scripts ﻿🤯

## Quickstart

```nushell no-run
> git clone https://github.com/nushell-prophet/dotnu; cd dotnu
> use dotnu
```

## Commands

### set-x

Let's check the code of the simple `set-x-demo.nu` script

```nushell
> let $filename = [tests assets set-x-demo.nu] | path join
> open $filename | lines | table -i false
╭──────────────╮
│ sleep 0.5sec │
│              │
│ sleep 0.7sec │
│              │
│ sleep 0.8sec │
╰──────────────╯
```

Let's see how `dotnu set-x` will modify this script

```nushell
> dotnu set-x $filename --echo | lines | table -i false
╭─────────────────────────────────────────────────────────────────────────────────╮
│ mut $prev_ts = date now                                                         │
│ print ("> sleep 0.5sec" | nu-highlight)                                         │
│ sleep 0.5sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
│                                                                                 │
│ print ("> sleep 0.7sec" | nu-highlight)                                         │
│ sleep 0.7sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
│                                                                                 │
│ print ("> sleep 0.8sec" | nu-highlight)                                         │
│ sleep 0.8sec                                                                    │
│ print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now); │
│                                                                                 │
╰─────────────────────────────────────────────────────────────────────────────────╯
```
