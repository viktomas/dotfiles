---
name: git-worktree
description: Git worktree and branch management using bare-repo layout. Use whenever the user mentions git worktree, creating a branch, or switching branches.
---

# Git Worktree Management

The user works with **bare-repo + worktree** layouts. Each repository has a `.bare/` directory (the actual git repo) and sibling directories for each worktree. There is no traditional checkout — every branch lives in its own directory.

`git wta` and `git wtu` are custom subcommands implemented as a **fish wrapper function** around `git` in `~/.config/fish/functions/git.fish`. The wrapper intercepts `wta` and `wtu`, passing everything else through to real `git`. Worktree creation and post-setup logic lives in `~/bin/git-wa.sh` (a bash script).

## Layout

```
/Users/tomas/workspace/gl/<project>/
├── .bare/          # bare git repo (the actual .git)
├── main/           # worktree tracking main branch
├── my-feature/     # worktree with branch tv/2026-03/my-feature
├── another-task/   # worktree with branch tv/2026-03/another-task
└── cleanup-worktrees.sh
```

Each worktree's `.git` file points back to `.bare/worktrees/<name>`.

## Creating a Worktree

**Always use `git wta`** (fish function) — never raw `git worktree add`:

```bash
fish -c 'cd /path/to/repo && git wta -n <name>'
```

This:
1. Fetches `origin/main`
2. Creates worktree at `<repo>/<name>/` with branch `tv/YYYY-MM/<name>` based on `origin/main`
3. Runs post-setup: `mise trust`, `npm ci`, `go mod download` (as applicable)
4. Changes into the new worktree directory

The branch naming convention is `tv/YYYY-MM/<name>` (e.g., `tv/2026-03/my-feature`).

## Updating Main Branch

**Use `git wtu`** to fast-forward the local main branch to match origin, without leaving your current directory:

```bash
git wtu
```

This auto-detects the main branch (`main` or `master`), fetches it, and fast-forwards the main worktree. Fails safely if there are local commits that prevent a fast-forward.

## Listing Worktrees

```bash
git worktree list
```

Run from any worktree or the `.bare/` directory.

## Cleaning Up Stale Worktrees

Some repos have a cleanup script that removes worktrees whose branches were deleted on origin:

```bash
./cleanup-worktrees.sh [--dry-run]
```

This fetches, prunes remote refs, then removes worktrees for branches that no longer exist on `origin`. Skips `main`/`master`. Use `--dry-run` to preview.

## Important Notes

- **Never `git checkout`** to switch branches — create a new worktree instead, or `cd` to an existing one.
- **Never `git worktree add` directly** — always use `git wta -n <name>` to get the correct branch naming and post-setup.
- The current working directory tells you which branch/worktree is active. The directory name matches the worktree name.
- To work on a different branch, just `cd` to its worktree directory.
- Each worktree is fully independent — its own `node_modules`, build artifacts, etc.
