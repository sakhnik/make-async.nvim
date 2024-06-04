# make-async.nvim

Execute make (or any shell command) without blocking Neovim and output to QuickFix.
Useful for long-running builds, especially with gradle. The QuickFix window will popup
automatically. The build can be interrupted with the conventional keystroke `CTRL-c`.

# Installation

Install with any package manager from `sakhnik/make-async.nvim`.

Initialize:

```
require'make-async.nvim'.setup {}
```

# Usage

## Make

Set `'makeprg'` to the desired command.

```
:set makeprg=./gradlew\ assemble
```

Then kick off the build:

```
:lua require'make-async.nvim'.make()
```

Or the same with a key mapping `<leader>mm`.

## A random shell command

If a shell command is to be executed without modifying `makeprg`, try this:

```
:X ./another-build-script.sh
```
