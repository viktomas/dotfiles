# Posting review comments on an MR

Only after I confirm. `post-comment.sh` posts **immediately** (`glab mr note create`)
and prepends `:robot: AI-generated` to every comment. For drafts, use the
`gitlab-mr-comments` skill instead.

```bash
S=~/.agents/skills/review/scripts/post-comment.sh

# Inline comment on an added/modified line (new side)
$S --mr <IID> --file path/to/file.ext --line 42 \
  --message "**[P1] Title**

Description of the issue."

# Inline comment on a removed line (old side)
$S --mr <IID> --file path/to/file.ext --old-line 10 --message "**[P2] Title** ..."

# Multiline comment (range on the new side)
$S --mr <IID> --file path/to/file.ext --line 42:48 --message "**[P1] Title** ..."

# General (non-positioned) comment
$S --mr <IID> --message "Overall: looks good!"

# Reply to an existing discussion
$S --mr <IID> --reply <discussion-id> --message "Fixed, thanks."
```

Line selection:
- Added or modified lines → `--line` (new side). Removed lines → `--old-line` (old side).
- `--line` and `--old-line` can't be combined.
- Pick the most relevant single line or narrowest range for the finding.

Without `glab` the script prints `posted: false` and the payload instead. Then skip the
script for the remaining comments and use the `create_merge_request_note` DWS tool
directly, prefixing every body with `:robot: AI-generated\n\n`. The context script
likewise points at the `get_merge_request` / `list_merge_request_diffs` DWS tools.
