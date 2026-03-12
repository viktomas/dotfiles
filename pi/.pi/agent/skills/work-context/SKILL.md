---
name: work-context
description: Context about MRs, issues, TODOs, and code reviews the user is working on. Use whenever the question could benefit from knowledge of their active work, projects, or collaborators. Use EVERY time I mention board. Use when asked to save/create a reference or look up a past reference.
---

# Work Context

All context about the user's current work — merge requests, issues, TODOs, code reviews, and project activity — lives in `/Users/tomas/workspace/gl/work`.

## When to Use This Skill

Load this skill whenever you sense the user's question could benefit from context about:

- Merge requests they authored or are reviewing
- GitLab TODOs, notifications, or action items
- Pipeline status, CI failures, or merge conflicts
- Code review threads or discussion history
- What they're currently working on or waiting on
- Any reference to specific MRs, issues, or people they collaborate with

Even if the user doesn't explicitly mention "work" or "MRs", use this skill if the question implies knowledge of their active projects or tasks.

Also load this skill when asked to save, create, or look up a **reference** — design decisions, patterns, or notes captured for future use.

## How to Get Context

1. **Read the project AGENTS.md** for full documentation on structure, scripts, and workflows:
   ```
   /Users/tomas/workspace/gl/work/AGENTS.md
   ```

2. **Quick overview of all MRs** — run:
   ```bash
   /Users/tomas/workspace/gl/work/scripts/mr-overview.sh
   ```

3. **TODOs and action items** — read:
   ```
   /Users/tomas/workspace/gl/work/todo.md
   ```

4. **Detailed MR state** — read files in:
   ```
   /Users/tomas/workspace/gl/work/mrs/<project>/*.md
   ```

5. **Kanban board** — read files in:
   ```
   /Users/tomas/workspace/gl/work/board/
   ```

   - todo.md
   - doing.md
   - waiting.md
   - done.md

6. **Refresh state** (if data may be stale) — run:
   ```bash
   /Users/tomas/workspace/gl/work/scripts/refresh.sh --hierarchical
   ```

7. **References** — reusable notes on patterns, design decisions, or research:
   ```
   /Users/tomas/workspace/gl/work/references/
   ```
   List files to find relevant references, or create new ones here when asked to save something for later.
