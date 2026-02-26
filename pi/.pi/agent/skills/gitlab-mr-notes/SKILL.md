---
name: gitlab-mr-notes
description: Read and display comments from GitLab merge requests - use when MR feedback is mentioned
---

# GitLab MR Notes

Read, create, and manage notes (comments) on GitLab merge requests using the `note` CLI, including general notes, diff notes, and draft reviews.

## Auto-detection

When run inside a git worktree whose branch has an open MR, `note` auto-detects the project and MR IID — no need to pass `--project` or `--mr`. You only need `--mr <iid>` if auto-detection fails or you want to target a different MR.

## Reading Notes

```bash
# List unresolved discussions on the current branch's MR
note list --state unresolved

# List all discussions (including resolved)
note list

# List only diff notes on a specific file
note list --filter diff --file src/main.ts

# JSON output for scripting
note list --json
```

### List Options

| Flag | Default | Description |
|------|---------|-------------|
| `--mr <iid>` | auto-detect from branch | MR IID |
| `--filter <type>` | `all` | `all`, `general`, `diff`, or `system` |
| `--state <state>` | `all` | `all`, `resolved`, or `unresolved` |
| `--file <path>` | (none) | Show only diff notes on this file |
| `--json` | false | Output as JSON |

### Output Format

```
#d1a2b3c4 [UNRESOLVED] src/example.ts:42 (diff)
  @alice (2024-01-15 10:30): This variable is unused.
  @bob   (2024-01-15 11:00): Fixed, thanks.

#e5f6a7b8 (general)
  @carol (2024-01-15 09:00): Can we add tests for the edge case?
```

Each discussion shows: discussion ID prefix (8 chars), resolution status (if resolvable), file:line (if diff), type, then indented notes with author and timestamp.

## Comment Formatting Convention

**MANDATORY**: ALL outgoing messages (comments, replies, issues, issue descriptions, draft notes, batch review bodies) MUST be prefixed with `:robot: AI-generated\n\n` followed by the actual content. This applies to every write operation without exception.

Pipe the comment via stdin to preserve formatting:

```bash
note create --file main.go --line 42 <<'EOF'
:robot: AI-generated

**Title of the finding**

Explanation of the problem in a paragraph.

Follow-up paragraph with more detail or a numbered list:

1. Step one
2. Step two

```go
// suggested fix
```
EOF
```

For inline `-m` flags:

```bash
note create -m ":robot: AI-generated

Looks good!"
```

For `glab issue create`, prefix the description:

```bash
glab issue create --title "..." --description ":robot: AI-generated

Issue body here..."
```

For batch review JSON, prefix each body:

```bash
echo '[{"file":"main.go","line":42,"body":":robot: AI-generated\n\nNit: rename this"}]' | note review --publish
```

## Creating Notes

Remember: ALL outgoing messages must be prefixed with `:robot: AI-generated\n\n`.

```bash
# General comment
note create -m ":robot: AI-generated

Looks good!"

# Diff comment on a specific line (new side)
note create --file main.go --line 42 -m ":robot: AI-generated

Nit: rename this"

# Multiline diff comment (lines 10 through 15)
note create --file main.go --line 10:15 -m ":robot: AI-generated

Refactor this block"

# Comment on a removed line (old side)
note create --file main.go --old-line 10 -m ":robot: AI-generated

Why was this removed?"

# Reply to a discussion (8-char prefix of discussion ID is enough)
note create --reply d1a2b3c4 -m ":robot: AI-generated

Good point, will fix."

# Body from stdin
echo ":robot: AI-generated

LGTM" | note create
```

## Draft Notes (Code Review Workflow)

Draft notes are visible only to you until published. Use them to batch review comments and publish them all at once.

```bash
# Create a draft general comment
note draft create -m ":robot: AI-generated

Needs work"

# Create a draft diff comment on a specific line
note draft create --file src/controller.ts --line 42 -m ":robot: AI-generated

Missing null check"

# Create a draft reply to a discussion (with auto-resolve on publish)
note draft create --reply abc12345 --resolve -m ":robot: AI-generated

Fixed"

# List your pending drafts
note draft list

# Publish all drafts at once
note draft publish
```

### Batch Review from JSON

```bash
echo '[{"file":"main.go","line":42,"body":":robot: AI-generated\n\nNit: rename this"}]' | note review --publish
```

## Managing Discussions

```bash
# Resolve/unresolve a discussion
note resolve d1a2b3c4
note unresolve d1a2b3c4
```

## Authentication

The tool uses `glab` CLI for GitLab authentication. Ensure you have:
1. `glab` installed and configured
2. Authenticated to the GitLab instance: `glab auth login`

## References

- `note --help`, `note create --help`, `note draft --help` for full CLI usage
- **references/REFERENCE.md** — GitLab API details and position object structure
