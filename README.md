# Dotfiles

On ubuntu machine:

1. Run sudo apt install git
1. git clone https://github.com/viktomas/dotfiles.git ~/.dotfiles
1. cd ~/.dotfiles
1. ./ubuntu-install-basic.sh
1. ./install.sh

## Bin

It's a good idea to start all the scripts with comma, so I can easily autocomplete only my personal commands https://rhodesmill.org/brandon/2009/commands-with-comma/ .

## Crontab

Edit crontab by running `./bin/edit-crontab.sh`.

## Git

- Configured to use different `.gitconfig` for work and private repos based on [How to use different git emails · Hao's learning log](https://blog.hao.dev/how-to-use-different-git-emails-for-personal-and-work-repositories-on-the-same-machine)

## Vim

### TODO

- [ ] use `pgrep -P $fish_pid nvim` to indicate that there is vim session in progress in the fish shell prompt
- [ ] autocomplete uses fuzzy matching, sometimes completing bullshit
- [ ] when I press `//` on visually selected text, I want the Telescope ripgrep to pre-populate the search
- [ ] somehow restore previous search for `//`
- [ ] I can't scroll through autocomplete options? :thinking: (C-P and C-N doesn't work in Go) I really need to sort it out.
- [ ] Copy key mappings from helix (space mode, go mode)
- [ ] try to use https://github.com/glepnir/lspsaga.nvim and see if it has better LSP rename
- [ ] replace all legacy `nvim_set_keymap` with `vim.keymap.set`
