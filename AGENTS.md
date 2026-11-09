`git wta -n <name>` creates a worktree with branch `tv/YYYY-MM/<name>` off `origin/main`.

## Local dev environment & config

Stow structure, per-tool setup, and install are documented in `README.md`
(each package also has its own README).

## Keyboard mapping

Home row mods (HRM) and the symbol layer are implemented in **kanata** —
`kanata/README.md` has the full layout and timings; `karabiner/README.md`
has the DriverKit dependency and migration notes.

## Scaffolding

Lessons go in `.agents/journal/` (append-only); AGENTS.md and skill changes
are proposed for review, never merged mid-task. `.agents/AUDIT.md` is the
running log and `.agents/check.sh` the validator. `.agents/` is repo state,
not a stow package — never add it to `install.sh`.
