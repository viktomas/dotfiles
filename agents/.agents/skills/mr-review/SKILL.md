---
name: mr-review
description: Review a GitLab merge request — read diffs, analyze changes, present findings, and optionally post comments on the MR
---

# MR Review

Review a GitLab merge request. Read the diffs, analyze the changes against a rubric, present findings, and optionally post comments on the MR.

## Helper Scripts

The skill provides two helper scripts in `./scripts/`.

- **`./scripts/get-mr-context.sh`** — Gathers MR metadata, branch state, review instructions, and diffs in one call.
- **`./scripts/post-comment.sh`** — Posts a review comment on the MR (positioned diff comment with `glab`, or payload for DWS tool fallback).

Both scripts auto-detect `glab` and adapt their behavior accordingly.

## Workflow

### 1. Get MR context (metadata + branch state + diffs)

Run the context script. Pass `--mr <IID>` if the user provided one, otherwise omit it and the script uses the current branch:

```bash
./scripts/get-mr-context.sh --mr <IID>
```

The script outputs structured sections (`=== TOOLS ===`, `=== BRANCH_STATE ===`, `=== MR_METADATA ===`, `=== REVIEW_INSTRUCTIONS ===`, `=== DIFFS ===`). Read the output and follow any `hint:` instructions — the script tells you when data is missing and what to do (e.g. use DWS tools, ask the user to choose a diff source, re-run with `--diff-source local` or `--diff-source remote`).

### 2. Analyze the diffs

Review each changed file against this rubric.

#### What to flag

Flag issues that:

1. Meaningfully impact correctness, performance, security, or maintainability.
2. Are discrete and actionable — one issue per finding.
3. Were **introduced by this MR** — not pre-existing code.
4. The author would likely fix if they knew about them.
5. Have provable impact — don't speculate that a change *might* break something; identify what it breaks.
6. Are clearly not intentional.

Do **not** flag:

- Style nits unless they obscure meaning or violate documented standards.
- Issues that demand rigor inconsistent with the rest of the codebase.
- Pre-existing bugs in unchanged code.

#### Categories

- **Correctness** — logic errors, edge cases, off-by-one, race conditions, null/undefined handling.
- **Security** — injection, auth bypass, secrets in code, unvalidated input, open redirects, non-parameterized SQL.
- **Maintainability** — unclear naming, excessive complexity, missing error handling, untested code paths.
- **Performance** — N+1 queries, unnecessary allocations, missing indexes, unbounded loops.

#### Priority levels

- **[P0]** Critical — bug or security issue that must be fixed before merge.
- **[P1]** Important — likely problem, should fix before merge.
- **[P2]** Suggestion — improvement worth considering.
- **[P3]** Nit — minor style or naming preference.

### 3. Present findings

Output a structured review:

```
## Review: <MR title> (!<IID>)

**Verdict**: Looks good / Needs attention

### Findings

**[P1] Title of finding**
File: `path/to/file.ext`, lines 42–48
Description of the issue and why it matters.

**[P2] Title of finding**
File: `path/to/file.ext`, line 15
Description.

---

Do you want me to post these as comments on the MR?
```

If there are no qualifying findings, explicitly state the code looks good.

Always ask before posting. Never post comments without user confirmation.

### 4. Post comments (only after user confirms)

Use the post-comment script. It auto-detects `glab` and falls back to outputting a payload for the `create_merge_request_note` DWS tool.

The script automatically prepends `:robot: AI-generated` to every comment.

```bash
# Inline diff comment on an added/modified line (new side)
./scripts/post-comment.sh --mr <IID> --file path/to/file.ext --line 42 \
  --message "**[P1] Title**

Description of the issue."

# Inline diff comment on a removed line (old side)
./scripts/post-comment.sh --mr <IID> --file path/to/file.ext --old-line 10 \
  --message "**[P2] Title**

Description."

# Multiline comment (range on new side)
./scripts/post-comment.sh --mr <IID> --file path/to/file.ext --line 42:48 \
  --message "**[P1] Title**

Description."

# General (non-positioned) comment
./scripts/post-comment.sh --mr <IID> --message "Overall: looks good!"

# Reply to an existing discussion
./scripts/post-comment.sh --mr <IID> --reply <discussion-id> --message "Fixed, thanks."
```

Line selection rules:
- For added or modified lines, use `--line` (targets the new side of the diff).
- For removed lines, use `--old-line` (targets the old side).
- `--line` and `--old-line` cannot be used together.
- Pick the most relevant single line or narrow range for the finding.

If the first call outputs `posted: false` (meaning `glab` is not available), skip the script for remaining comments and use the `create_merge_request_note` DWS tool directly. Prefix every comment body with `:robot: AI-generated\n\n`.
