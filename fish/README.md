# Fish shell

Fish is the user's shell. Config is stow-managed:
`fish/.config/fish/` → `~/.config/fish/`.

Use fish syntax for anything touching the environment (aliases, config, env
vars, PATH).

- Test commands with `fish -c '<command>'`.
- Config that only loads in interactive mode (abbreviations, key bindings) needs
  `fish -ic '<command>'`.

## Wrapper functions for global npm tools

`fish/.config/fish/functions/{pi,qmd}.fish` pin `node@24` at runtime so the
mise-managed global npm tools work regardless of a project's local node version.
See `../pi/README.md` for the full pi & qmd setup.
