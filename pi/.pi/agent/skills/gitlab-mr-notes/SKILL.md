---
name: gitlab-mr-notes
description: Read and display notes (comments) from GitLab merge requests, including diff notes with position information
---

# GitLab MR Notes Reader

Read all notes (comments) from GitLab merge requests, including both general notes and diff notes with their position information in the diff.

## Basic Usage

```bash
# Read unresolved notes from current branch's MR (default)
~/.pi/skills/gitlab-mr-notes/scripts/read_mr_notes.js

# Read all notes including resolved ones from current branch's MR
~/.pi/skills/gitlab-mr-notes/scripts/read_mr_notes.js --all

# Read notes from a specific MR URL
~/.pi/skills/gitlab-mr-notes/scripts/read_mr_notes.js --url \
  https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870

# Read all notes from a specific MR URL
~/.pi/skills/gitlab-mr-notes/scripts/read_mr_notes.js --all --url \
  https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870
```

## Options

- `--all`, `-a`: Show all discussions including resolved ones. By default, only unresolved discussions are shown.
- `--url <MR_URL>`: Specify a specific MR URL. By default, uses the MR associated with the current branch.

## Output Format

The script outputs notes in a structured format:

### General Notes (not attached to code)
```
[GENERAL NOTE]
Author: @username (Full Name)
Created: 2024-01-15T10:30:00Z
Resolved: false

Comment body text here...
---
```

### Diff Notes (attached to specific lines)
```
[DIFF NOTE]
Author: @username (Full Name)
Created: 2024-01-15T10:30:00Z
File: src/example.ts
Position: Line 42 (ADDED) in head commit abc123
Resolved: false

Comment body text here...
---
```

Position types:
- **ADDED**: Comment on newly added code (`newLine` set, `oldLine` null)
- **REMOVED**: Comment on deleted code (`oldLine` set, `newLine` null)  
- **UNCHANGED**: Comment on existing code (both `newLine` and `oldLine` set)

## Authentication

The script uses `glab` CLI for GitLab authentication. Ensure you have:
1. `glab` installed and configured
2. Authenticated to the GitLab instance: `glab auth login`

## Requirements

- `glab` - GitLab CLI tool
- `jq` - JSON processor
- `node` - Node.js runtime

## See Also

- **references/REFERENCE.md** - Implementation details and GitLab API notes
- **scripts/read_mr_notes.js** - Main implementation script
