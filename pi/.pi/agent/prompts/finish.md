---
description: Finish task
---
The work has been done. Update the task file. Summarise what we've done on this branch, link all issues and MRs in the task file if they haven't been linked already. Don't rewrite much of the task file, only if there were TODOs or other "todo like" items, delete them.

Then clean up the worktree and finish the task in a **single bash call** (because each bash invocation uses the original cwd, and `task done` kills the session):

```bash
worktree_name=$(basename "$PWD") && cd .. && git worktree remove "$worktree_name" && task done --on-user-request
```
