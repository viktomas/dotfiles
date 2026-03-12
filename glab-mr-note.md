# glab mr note

Read, create, and manage notes (comments) on GitLab merge requests using `glab mr note`, including general notes, diff notes, and draft reviews.

## CRITICAL: Publishing Rules

**NEVER publish notes directly without explicit user approval.** Follow these rules:

1. **Replying to existing threads/discussions** → use `glab mr note draft create --reply <id>` (draft note). This keeps replies invisible until the user publishes.
2. **New comments on diff lines** → ask the user for permission before creating. Show them the comment text and target location first. If approved, use `glab mr note draft create`.
3. **General comments** → ask the user for permission before creating. If approved, use `glab mr note draft create`.
4. **Publishing drafts** → NEVER run `glab mr note draft publish` without the user saying to publish. After creating drafts, tell the user what's pending and let them decide when to publish.
5. **`glab mr note`** (published immediately) → only use when the user explicitly says to publish/post/submit a note right now.

In short: **default to drafts, ask before publishing.**

## Auto-detection

When run inside a git worktree whose branch has an open MR, `glab mr note` auto-detects the project and MR IID — no flags needed. Pass an MR IID as a positional argument if auto-detection fails or you want to target a different MR.

## Reading Notes

```bash
# List unresolved discussions on the current branch's MR
glab mr note list --state unresolved

# List all discussions (including resolved)
glab mr note list

# List only diff notes on a specific file
glab mr note list --filter diff --file src/main.ts

# JSON output for scripting
glab mr note list --json

# List discussions on MR 123
glab mr note list 123
```

### List Options

| Flag | Default | Description |
|------|---------|-------------|
| `<id>` (positional) | auto-detect from branch | MR IID |
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

**MANDATORY**: ALL outgoing messages (comments, replies, draft notes, batch review bodies) MUST be prefixed with `:robot: AI-generated\n\n` followed by the actual content. This applies to every write operation without exception.

Pipe the comment via stdin to preserve formatting:

```bash
glab mr note draft create --file main.go --line 42 <<'EOF'
:robot: AI-generated

**Title of the finding**

Explanation of the problem in a paragraph.

```go
// suggested fix
```
EOF
```

For inline `-m` flags:

```bash
glab mr note draft create -m ":robot: AI-generated

Looks good!"
```

For batch review JSON, prefix each body:

```bash
echo '[{"file":"main.go","line":42,"body":":robot: AI-generated\n\nNit: rename this"}]' | glab mr note review
```

## Creating Notes (Drafts by Default)

Remember: ALL outgoing messages must be prefixed with `:robot: AI-generated\n\n`.

### Draft replies to existing discussions (preferred)

```bash
# Reply to a discussion as draft
glab mr note draft create --reply d1a2b3c4 -m ":robot: AI-generated

Good point, will fix."

# Reply and auto-resolve on publish
glab mr note draft create --reply d1a2b3c4 --resolve -m ":robot: AI-generated

Fixed in latest push."
```

### Draft comments on diff lines

```bash
# Draft diff comment on a specific line (new side)
glab mr note draft create --file main.go --line 42 -m ":robot: AI-generated

Nit: rename this"

# Multiline diff comment (lines 10 through 15)
glab mr note draft create --file main.go --line 10:15 -m ":robot: AI-generated

Refactor this block"

# Comment on a removed line (old side)
glab mr note draft create --file main.go --old-line 10 -m ":robot: AI-generated

Why was this removed?"
```

### Draft general comments

```bash
glab mr note draft create -m ":robot: AI-generated

Needs work"
```

### Managing drafts

```bash
# List your pending drafts
glab mr note draft list

# JSON output
glab mr note draft list --json

# Publish all drafts (ONLY when user explicitly asks)
glab mr note draft publish --all

# Publish a single draft
glab mr note draft publish <draft-id>
```

### Published notes (only with explicit user approval)

Use `glab mr note` (without `draft`) only when the user explicitly says to publish immediately:

```bash
# Published general comment
glab mr note -m ":robot: AI-generated

Looks good!"

# Published reply
glab mr note --reply d1a2b3c4 -m ":robot: AI-generated

Good point, will fix."

# Published diff comment
glab mr note --file main.go --line 42 -m ":robot: AI-generated

Nit: rename this"

# Published confidential internal note
glab mr note --internal -m ":robot: AI-generated

Internal feedback for maintainers"

# Body from stdin
echo ":robot: AI-generated

LGTM" | glab mr note
```

### Batch Review from JSON

```bash
# Creates drafts (don't add --publish without user approval)
echo '[{"file":"main.go","line":42,"body":":robot: AI-generated\n\nNit: rename this"}]' | glab mr note review

# Create and publish in one step (only with explicit user approval)
echo '[{"body":":robot: AI-generated\n\nLGTM"}]' | glab mr note review --publish
```

JSON array format — each object can have:
- `body` (string, required): Note text in Markdown
- `file` (string): File path for a diff comment
- `line` (string or number): New-side line or range `"N:M"`; requires `file`
- `old_line` (number): Old-side line; requires `file`
- `reply` (string): Discussion ID or 8+ char prefix
- `resolve` (bool): Resolve discussion on publish; requires `reply`

## Managing Discussions

```bash
# Resolve a discussion
glab mr note resolve <discussion-id>

# Unresolve a discussion
glab mr note unresolve <discussion-id>

# Target a specific MR
glab mr note resolve <discussion-id> 123
```

Discussion IDs can be the full 40-character hex string or an 8+ character prefix.

## Authentication

Uses `glab` CLI for GitLab authentication. Ensure:
1. `glab` is installed and configured
2. Authenticated to the GitLab instance: `glab auth login`
