<h1 align="center">generate scripts from .nu scripts ﻿🤯</h1>

## Quickstart

```nushell no-run
> git clone https://github.com/nushell-prophet/dotnu; cd dotnu
> use dotnu
```

## Commands

### set-x

```nushell indent-output
# Let's check the code of a simple `.nu` script
> open tests-related/set-x-demo.nu
//  sleep 0.5sec
//
//  sleep 0.7sec
//
//  sleep 0.8sec
# Let's see how `dotnu set-x` will modify this script
> dotnu set-x tests-related/set-x-demo.nu --echo
//  mut $prev_ts = date now
//  print "> sleep 0.5sec"
//  sleep 0.5sec
//  print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);
//
//
//  print "> sleep 0.7sec"
//  sleep 0.7sec
//  print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);
//
//
//  print "> sleep 0.8sec"
//  sleep 0.8sec
//  print $'(ansi grey)((date now) - $prev_ts)(ansi reset)'; $prev_ts = (date now);
//
```
