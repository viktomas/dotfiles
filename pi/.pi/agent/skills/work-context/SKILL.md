---
name: work-context
description: Use when I mention work context or when I talk about issue/MR that you verified is not directly assigned to the current branch or is not linked. Can be used for semantic search through all my work items.
---

All context about the user's current work — merge requests, issues, TODOs, code reviews, and project activity — lives in 

```
/Users/tomas/workspace/gl/work
```

If term looks super specific, use (rip) grep to search the folder, otherwise use Semantic search

## Semantic search

   **Semantic search across all work notes** — the entire `/Users/tomas/workspace/gl/work` tree (including `references/`, `mrs/`, `board/`, `todo.md`) is indexed by `qmd`. Use it when looking for a past reference, decision, or note by topic rather than by filename:
   ```bash
   qmd query "<topic or question>" -c work
   ```

For semantic search it's better to use a sentence rather than a single word

## Creating new references

**References** — reusable notes on patterns, design decisions, or research:

```
/Users/tomas/workspace/gl/work/references/
```

List files to find relevant references, or create new ones here when asked to save something for later.


8. **Task sessions** — board items can link to zellij task sessions via `$slug` annotations on headings. Full CLI reference and conventions are in the **task-management** skill. Task CLI source and tests live in `/Users/tomas/workspace/gl/task/main/`.
