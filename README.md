# Utilities for the Elvish shell

This project provides modules useful to a user of the
[Elvish shell](https://elv.sh/). For example, a mechanism for displaying the
duration of an interactive statement in your left or right prompt.

## Installation

Using the [Elvish package manager](https://elv.sh/ref/epm.html):

```shell
use epm
epm:install github.com/krader1961/elvish-lib
```

## Displaying command duration in an interactive prompt

Add the following to your _~/.elvish/rc.elv_ file:

```shell
use github.com/krader1961/elvish-lib/cmd-duration
```

Then simply include `(cmd-duration:human-readable)` in your left or right prompt
definition. If you are using the
[github.com/zzamboni/elvish-themes/chain](https://github.com/zzamboni/elvish-themes/chain)
module you probably want something like the following in your _~/.elvish/rc.elv_
config script:

```shell
use github.com/zzamboni/elvish-themes/chain

chain:segment-style[cmd-duration] = [bg-bright-cyan fg-black]

fn cmd-duration-segment []{
    chain:prompt-segment cmd-duration (cmd-duration:human-readable)
}

chain:rprompt-segments = [ $cmd-duration-segment~ ]
```
