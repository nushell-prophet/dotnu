<h1 align="center">generate scripts from .nu scripts ﻿🤯</h1>
## Commands

```nushell
> use dotnu *
> extract -h
extract a command from a module and save it as a file, that can be sourced

Usage:
  > intermid.nu {flags} <$file> <$command>

Flags:
  --output <Filepath> - a file path to save extracted command script
  -h, --help - Display the help message for this command

Parameters:
  $file <path>: a file of a module to extract a command from
  $command <string>: the name of the command to extract

Input/output types:
  ╭───┬───────┬────────╮
  │ # │ input │ output │
  ├───┼───────┼────────┤
  │ 0 │ any   │ any    │
  ╰───┴───────┴────────╯

> set-x -h
create a file that will print and execute all the commands by blocks.
Blocks are separated by empty lines between commands.

Usage:
  > intermid.nu <file>

Flags:
  -h, --help - Display the help message for this command

Parameters:
  file <path>: path to `.nu` file

Input/output types:
  ╭───┬───────┬────────╮
  │ # │ input │ output │
  ├───┼───────┼────────┤
  │ 0 │ any   │ any    │
  ╰───┴───────┴────────╯
```
