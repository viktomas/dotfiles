## Fork/Renovate MR Branches

MRs from forks (e.g. renovate bot) have `source_project_id ≠ target_project_id`. Their branches don't exist on `origin`, so `git fetch origin <branch>` will fail. **Don't try to check out the fork branch.** Instead:

1. Create a new branch from `origin/main` (using `git wta`)
2. Make the fix yourself
3. Push your branch and create a new MR (close the bot's MR or let it auto-close)

This is common with renovate dependency MRs that fail artifact updates (e.g. Go module path changes that renovate can't handle).

## Pushing Fork Branches

`push.default` is set to `simple`. For the branch's tracking remote, `git push` pushes there (not `origin`) — but only if the local and remote branch names match; otherwise it refuses. When a branch tracks a fork remote (e.g. `gitlab-renovate-forks`) with a matching branch name, a plain `git push` pushes there.

Always verify the tracking remote before pushing fork branches:

```bash
git branch -vv          # shows [remote/branch] tracking info
git push                # pushes to tracked remote
```

If the branch name on the remote differs from the local branch name (common with fork worktrees where local name is `fork/<remote>/<branch>` but the remote branch is just `<branch>`), specify the refspec:

```bash
git push <fork-remote> HEAD:<remote-branch-name>
```

## ⚠️ Pre-push Hooks Can Corrupt Worktree State

**Root cause**: Git sets `GIT_WORK_TREE` during hook execution. This leaks into test subprocesses, causing lefthook hooks from `.bare/hooks/` to fire in test temp repos. Only happens inside hooks (pre-push, pre-commit), not when running `make test-changed` directly.

Symptoms after a failed pre-push hook:
1. **Wrong branch** — test did `git checkout -b BranchN` and failed before cleanup
2. **Wrong git config** — test wrote `user.name "glab test bot"` to worktree config
3. **Test failures** — lefthook rejects test commits, cmdtest binary builds fail

**After a failed pre-push hook**, always verify:
```bash
git branch              # should show your branch, not "Branch12" etc.
git config user.name    # should be your name, not "glab test bot"
```

To fix: `git checkout <your-branch>`, `git config --unset user.name`, `git config --unset user.email`.

To avoid: push with `--no-verify` when pre-push tests are known-flaky in worktrees, or set `LEFTHOOK=0`.

Tracked in: https://gitlab.com/gitlab-org/cli/-/work_items/8223

# `core.bare` Must Be `true` in `.bare/config`

The `.bare/config` file **must** have `core.bare = true`. If it's `false`, git treats `.bare` as a non-bare repo with a working tree, and its `HEAD` (which typically points to `refs/heads/main`) counts as "main is checked out here" — blocking any worktree from using the `main` branch.

## Symptom

`git checkout main` in a worktree fails with:
```
fatal: 'main' is already used by worktree at '/path/to/.bare'
```

And `git worktree list` shows `.bare` as `[main]` instead of `(bare)`.

## Diagnosis

```bash
git -C /path/to/.bare config core.bare   # should print "true"
git worktree list                         # .bare line should show (bare), not [main]
```

## Fix

```bash
git -C /path/to/.bare config core.bare true
```
