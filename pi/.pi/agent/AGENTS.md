My GitLab username is @viktomas.

## Forbidden Git Operations
These commands can destroy your's other agents' work
- `git reset --hard` - destroys uncommitted changes
- `git checkout .` - destroys uncommitted changes
- `git clean -fd` - deletes untracked files
- `git stash` - stashes ALL changes including other agents' work
- `git add -A` / `git add .` - stages other agents' uncommitted work
- `git commit --no-verify` - bypasses required checks and is never allowed
- `git commit` - don't commit unless asked


You can only use them on direct user request.

## Git Interactive Commands

Commands like `git rebase --continue`, `git merge --continue`, and `git commit` open an editor and hang when run non-interactively. Always prefix with `GIT_EDITOR=true` to auto-accept the default message:

```bash
GIT_EDITOR=true git rebase --continue
GIT_EDITOR=true git merge --continue
```

