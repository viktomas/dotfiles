---
name: gitlab-api
description: Interact with GitLab REST API using GITLAB_TOKEN - use for TODOs, projects, issues, and other API queries
---

# GitLab API

Prefer `glab` CLI commands over raw `curl`. Use `glab api` for endpoints without a dedicated subcommand. Fall back to `curl` only when `glab` doesn't work (documented below).

**IMPORTANT**: If you encounter a `glab` command that fails, behaves unexpectedly, or is missing functionality, you MUST update this skill file to document the issue — either by adding a curl fallback with an explanation, or by adding a warning note to the relevant section. This keeps the skill accurate for future use.

When running from a git worktree of the target project, `glab` auto-detects the repo. Otherwise use `-R OWNER/REPO`.

## glab — Pipelines & Jobs

### View current branch pipeline status

```bash
glab ci status                     # interactive view
glab ci status -F json             # JSON output
glab ci status --compact           # compact text view
```

### List pipelines

```bash
glab ci list -F json                          # all pipelines
glab ci list --status=failed -F json          # only failed
glab ci list --ref=my-branch -F json          # specific branch
```

### Get pipeline details (with job info)

```bash
glab ci get -F json                           # current branch, latest pipeline
glab ci get -p <pipeline_id> -F json          # specific pipeline
glab ci get -d -F json                        # with extended job details
```

### Retry a job

```bash
glab ci retry <job-id>             # retry by job ID
glab ci retry <job-name>           # retry by job name
glab ci retry                      # interactive selection
```

### View job log

```bash
glab ci trace <job-id>             # stream job log
```

### Waiting for pipelines — early failure detection

**⚠️ Don't wait for `pipeline.status` alone.** A pipeline stays `running` even when jobs have already failed (other jobs are still executing). This wastes minutes waiting for a result you could detect immediately.

Instead, check for non-allowable failed jobs to detect failure early while the pipeline is still running:

```bash
# Early failure: exits 0 if any non-allow_failure job has failed (pipeline will inevitably fail)
glab api "projects/:id/pipelines/<pipeline_id>/jobs?per_page=100" \
  | jq -e '[.[] | select(.status == "failed" and .allow_failure == false)] | length > 0'

# Full condition: pipeline finished OR has a non-recoverable failure
# Use this as your wait-for command:
PIPELINE_ID=<id>; \
glab mr view <iid> -F json | jq -e '.pipeline.status == "success" or .pipeline.status == "failed"' 2>/dev/null \
|| glab api "projects/:id/pipelines/$PIPELINE_ID/jobs?per_page=100" \
  | jq -e '[.[] | select(.status == "failed" and .allow_failure == false)] | length > 0'
```

The combined check exits 0 when either:
1. The pipeline has fully completed (success or failed), OR
2. A required job has already failed (pipeline is doomed even though it's still "running")

## glab — Issues

### Create an issue

```bash
glab issue create --title "..." --description ":robot: AI-generated

Issue body here..." -R OWNER/REPO
```

## glab — Merge Requests

### View MR details

```bash
glab mr view <iid> -F json
glab mr view <branch> -F json
```

### List MRs

```bash
glab mr list -F json
glab mr list --assignee=@me -F json
glab mr list --reviewer=@me -F json
glab mr list --source-branch=my-branch -F json
```

### Merge an MR

```bash
glab mr merge <iid> --auto-merge --squash --remove-source-branch -y
```

**⚠️ NEVER use `glab mr merge` on projects with merge trains enabled** (cli, gitlab-lsp). It calls the Accept MR API which bypasses the merge train entirely — if the pipeline is already green, it merges directly to the target branch without a merge-train pipeline. This can break main. Always use the merge train curl fallback below instead.

Projects with merge trains enabled: `gitlab-org/cli` (34675721), `gitlab-org/editor-extensions/gitlab-lsp` (46519181).

## glab api — Generic API Access

Use `glab api` for any REST endpoint not covered by a dedicated subcommand. It handles auth automatically. Supports `:id` (project ID), `:fullpath`, `:repo` placeholders when run from a project directory.

```bash
# List MR pipelines (no dedicated glab subcommand for MR-specific pipelines)
glab api "projects/:id/merge_requests/<mr_iid>/pipelines?per_page=5" | jq '.[] | {id, status, source, ref}'

# List failed jobs in a pipeline
glab api "projects/:id/pipelines/<pipeline_id>/jobs?per_page=100" | jq '.[] | select(.status == "failed") | {id, name, stage, web_url}'

# Retry an entire pipeline
glab api -X POST "projects/:id/pipelines/<pipeline_id>/retry" | jq '{id, status, ref}'
```

Merge train pipelines have `ref: "refs/merge-requests/<iid>/train"`.

## glab — To-Do List

Uses helper scripts in `scripts/` relative to this skill directory.

### List TODOs

```bash
scripts/list-todos.sh [--state pending|done] [--action ACTION] [--type TYPE] [--per-page N]
```

Defaults to `--state pending --per-page 50`.

**Action filter values**: `assigned`, `mentioned`, `build_failed`, `marked`, `approval_required`, `unmergeable`, `directly_addressed`, `merge_train_removed`, `review_requested`, `member_access_requested`

**Type filter values**: `Issue`, `MergeRequest`, `Commit`, `Epic`, `DesignManagement::Design`, `AlertManagement::Alert`, `Project`, `Namespace`, `Vulnerability`, `WikiPage::Meta`

```bash
scripts/list-todos.sh                                    # all pending
scripts/list-todos.sh --action review_requested          # only review requests
scripts/list-todos.sh --state done --type MergeRequest   # done MR TODOs
```

### Mark a Single TODO as Done

```bash
scripts/mark-todo-done.sh <todo_id>
```

The `todo_id` is shown in `list-todos.sh` output as `(id:NNN)`.

---

## curl Fallback

Use these only when `glab` / `glab api` doesn't cover the use case.

Common project IDs: `278964` (gitlab-org/gitlab), `46519181` (gitlab-org/editor-extensions/gitlab-lsp), `34675721` (gitlab-org/cli).

### Award Emoji (Reactions)

No `glab` subcommand exists for award emoji.

```bash
# React to a note (comment) on an MR
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<mr_iid>/notes/<note_id>/award_emoji" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name": "<emoji_name>"}'

# React to an MR itself
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<mr_iid>/award_emoji" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name": "<emoji_name>"}'
```

### Merge Trains

**Always use the merge train API for projects with merge trains enabled.** `glab mr merge` uses the Accept MR API which bypasses the merge train — even with `--auto-merge`, if the pipeline is green it merges directly without a merge-train pipeline.

```bash
# List active merge train entries
curl -s "https://gitlab.com/api/v4/projects/<project_id>/merge_trains?per_page=10" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | {merge_request: .merge_request.iid, status}'

# Add MR to merge train (THE correct way to merge on merge-train projects)
# Do NOT pass auto_merge:true — it returns 400 when pipeline already succeeded
# (bug: https://gitlab.com/gitlab-org/gitlab/-/work_items/592889)
# Omitting auto_merge adds to the train immediately, which is what we want.
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_trains/merge_requests/<mr_iid>" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"squash": true}'
```

**Why not the Accept MR API?** `PUT /merge_requests/:iid/merge` with `auto_merge=true` on a merge-train project will merge **directly** when the pipeline is green, completely bypassing the merge train ([#552045](https://gitlab.com/gitlab-org/gitlab/-/work_items/552045)). This is "by design" — the Accept API is the "merge immediately" endpoint.

Projects with merge trains: `gitlab-org/cli` (34675721), `gitlab-org/editor-extensions/gitlab-lsp` (46519181).

## API Documentation

For exploring GitLab API endpoints and parameters, check the local GDK docs at `/Users/tomas/workspace/gl/gdk/gitlab/doc/api/`. These are the source `.md` files for the official GitLab API docs.

## References

Detailed docs for niche APIs live in `references/` next to this file. Read them when the topic comes up.

| File | Topic |
|------|-------|
| `references/duo-workflows-api.md` | Duo Workflows checkpoint API — creating workflows, posting checkpoints, `ui_chat_log` shape, direct-access tokens |
