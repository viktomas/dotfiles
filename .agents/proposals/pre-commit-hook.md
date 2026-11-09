# Proposal: pre-commit hook scoped to scaffolding paths

**Status: installed 2026-11-09** (owner approved). Live via
`git config core.hooksPath .agents/hooks`; the hook lives at
`.agents/hooks/pre-commit`. Verified: data-only staging exits in ~25 ms
without running the check; scaffolding staging runs check.sh; a real
violation (AGENTS.md over budget) blocks the commit with exit 1.
This file stays as the decision record.

## What changes

A versioned hook at `.agents/hooks/pre-commit`, activated once by the
owner with `git config core.hooksPath .agents/hooks`. It runs
`.agents/check.sh` only when scaffolding paths are staged:

```sh
#!/bin/sh
# pre-commit - run the scaffolding check only when scaffolding paths are
# staged, so data/config commits stay fast and are never blocked.
# Activated by: git config core.hooksPath .agents/hooks
# Revert:      git config --unset core.hooksPath && rm -r .agents/hooks

changed=$(git diff --cached --name-only |
  grep -E '^(AGENTS\.md|\.pi/|\.agents/)' || true)
[ -n "$changed" ] || exit 0

echo "scaffolding paths staged - running .agents/check.sh" >&2
sh .agents/check.sh
```

Notes, from the agent-scaffolding operational gotchas:

- Scope is `AGENTS.md`, `.pi/`, `.agents/` — not `scripts/` like the
  gotchas' example, because this repo's scaffolding lives in those three
  paths (the check validator itself iterates `.pi/skills/*/`).
- `check.sh` currently calls no git, so the gotcha about unsetting
  `GIT_INDEX_FILE` / `GIT_DIR` / `GIT_WORK_TREE` does not apply yet; if
  the check ever grows a git call, unset them in the hook first.
- Non-zero exit blocks the commit (plain git semantics — no Claude-Code
  exit-code-2 subtleties here).

## Principle

2 (mechanism over prose) and 10 (errors are context): the AGENTS.md
budget, the skill validator and the stow guard already exist as
`.agents/check.sh`, but nothing runs them — "run it before committing
scaffolding" is prose this repo cannot enforce. There is no CI, so a
pre-commit hook is the nearest equivalent and the only always-run
mechanism that also covers human commits.

## Cost

- Data/config commits: one `git diff --cached --name-only | grep`, ~ms.
- Scaffolding commits: one run of `check.sh` (greps + sed, < 1 s).
- Maintenance: if `check.sh` turns noisy, commits block — the same
  failure mode the guidelines warn about for all hooks.

## Benefit

A direct commit that breaks the AGENTS.md budget, a skill's frontmatter,
or adds `stow .agents` to install.sh cannot land, for humans or agents,
without a deliberate `--no-verify`. Without it, `check.sh` is advisory.

## Revert

`git config --unset core.hooksPath` and `rm -r .agents/hooks` — no other
state.
