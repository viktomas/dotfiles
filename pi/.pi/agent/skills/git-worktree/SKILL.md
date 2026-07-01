---
name: git-worktree
description: Use whenever the user mentions git worktree, creating a branch, or switching branches. Keywords - worktree, git wta, git wtu, bare repo, new branch, create branch.
---

## Projects

I use a specific worktree layout in several of my projects:

- /Users/tomas/workspace/gl/gitlab-vscode-extension
- /Users/tomas/workspace/gl/gitlab-lsp
- /Users/tomas/workspace/gl/cli
- /Users/tomas/workspace/gl/task

## Layout

For these repositories, the layout is:

```
/Users/tomas/workspace/gl/<project>/
├── .bare/          # bare git repo (the actual .git)
├── main/           # worktree tracking main branch
├── my-feature/     # worktree with branch tv/2026-03/my-feature
├── another-task/   # worktree with branch tv/2026-03/another-task
└── cleanup-worktrees.sh
```

## Create

I have a `git wta` fish script to create a new worktree, always use:

```bash
fish -c 'cd /path/to/repo && git wta <name/MR URL>'
```

- If the `name` branch already exists in the remote, the command will check it out.
- Otherwise it creates `tv/YYYY-MM/name` branch in `name` subfolder
- If the `name` contains slashes, they get escaped as dashes in the subfolder name.

Then it _quietly_ runs package manger to install dependencies (`mise trust` then it runs `npm` or `bun` or `go mod`)

If you pass MR URL, it will create worktree for the MR branch.

## Update

```bash
fish -c 'cd /path/to/repo && git wtu'
```

Updates the `main` branch in the `main` folder to the latest origin version

## Cleanup

Some repos have a cleanup script that removes worktrees whose branches were deleted on origin:

```bash
/path/to/repo/cleanup-worktrees.sh [--dry-run]
```

## Debugging

If you face issues with worktrees, load [debbuging.md](./references/debugging.md).
