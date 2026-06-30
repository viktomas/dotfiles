---
name: projects
description: Tomas's projects — what they are and where they live on the local drive. Use whenever a question references a project by name, alias, or path, or when you need to locate a repo locally. Keywords - project, repo, where does X live, local path, gitlab-lsp, glab, cli, vscode extension, note, task, duo cli.
---

# Projects

Tomas (@viktomas) is a GitLab engineer working primarily on **GitLab Duo** developer
tooling — the AI features (code completion, chat, agentic chat, flows). Day-to-day
work centers on the GitLab Language Server / Duo CLI, with a strong focus on the
CLI and TUI, plus build/test/verification infrastructure.

All repos live under `/Users/tomas/workspace/gl/`.

## Core Projects

| Project | Local Root | Worktrees | What it is |
|---------|-----------|-----------|------------|
| `gitlab-org/editor-extensions/gitlab-lsp` | `/Users/tomas/workspace/gl/gitlab-lsp` | ✅ | GitLab Language Server — powers Duo completion, chat, agentic flows, the Duo CLI & TUI. **Primary project.** |
| `gitlab-org/cli` | `/Users/tomas/workspace/gl/cli` | ✅ | Official GitLab CLI (`glab`). |
| `gitlab-org/gitlab-vscode-extension` | `/Users/tomas/workspace/gl/gitlab-vscode-extension` | ✅ | VS Code extension (reviewer). |
| `viktomas/note` | `/Users/tomas/workspace/gl/note` | ❌ | Personal CLI for MR comments/notes; being upstreamed into `glab mr note`. |
| `viktomas/task` | `/Users/tomas/workspace/gl/task` | ✅ | Personal task-session CLI. |

Other GitLab repos (the monolith, build-images, etc.) are cloned under
`/Users/tomas/workspace/gl/` as well — e.g. `gdk`, `gitlab-runner`, `gitlab-ui`,
`needle`. Browse `/Users/tomas/workspace/gl/` to find a repo by name.

## Worktrees

`gitlab-lsp` (and some others) use a **bare-repo + worktree** layout: each
subdirectory is a separate working tree for a branch, e.g.
`gitlab-lsp/main`, `gitlab-lsp/<feature-branch>`. Don't be confused by the
one-level subfolder named after a branch. See the `git-worktree` skill.

## Related Skills

- **work-context** — live MRs, issues, TODOs, tasks, and themes (the source of truth for *current* work). Lives in `/Users/tomas/workspace/gl/work`.
- **git-worktree** — worktree/branch management for the bare-repo layout.
