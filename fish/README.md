# Fish shell

Fish is the user's shell. Config is stow-managed:
`fish/.config/fish/` → `~/.config/fish/`.

Use fish syntax for anything touching the environment (aliases, config, env
vars, PATH).

- Test commands with `fish -c '<command>'`.
- Config that only loads in interactive mode (abbreviations, key bindings) needs
  `fish -ic '<command>'`.

## fzf key bindings (insert mode)

- `alt+f` (`fzf_file`): fzf over the whole current git repo (tracked +
  untracked, ignored excluded; `fd --hidden` outside a repo) and insert the
  picked file's path at the cursor — relative to the cwd, shell-escaped, so
  `open <alt+f>` works from any subdir. The current token pre-fills the
  fzf query. Chord: hold `l` (right ring = alt), tap `f` (left) — must be
  opposite hands (kanata same-hand rule); skhd leaves alt-f alone.
- Also: `alt+l` (`fzf_git_log`, hold `s`, tap `l`), `ctrl-alt-p`
  (`fzf_process_search`, still multi-mod), `\cr` (`fzf_history_search`) — see
  `config.fish`. (yabai/skhd are unused, so alt chords are free.)

## Wrapper functions for global npm tools

`fish/.config/fish/functions/{pi,qmd}.fish` pin `node@24` at runtime so the
mise-managed global npm tools work regardless of a project's local node version.
See `../pi/README.md` for the full pi & qmd setup.
