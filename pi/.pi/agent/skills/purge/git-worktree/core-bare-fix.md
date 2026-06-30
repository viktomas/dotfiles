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
