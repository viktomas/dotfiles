---
name: gitlab-api
description: Interact with GitLab REST API using GITLAB_TOKEN - use for TODOs, projects, issues, and other API queries
---

# GitLab API

Query the GitLab REST API using `GITLAB_TOKEN` (always present in environment).

All scripts live in `scripts/` relative to this skill directory.

## To-Do List

### List TODOs

```bash
scripts/list-todos.sh [--state pending|done] [--action ACTION] [--type TYPE] [--per-page N]
```

Defaults to `--state pending --per-page 50`.

**Action filter values**: `assigned`, `mentioned`, `build_failed`, `marked`, `approval_required`, `unmergeable`, `directly_addressed`, `merge_train_removed`, `review_requested`, `member_access_requested`

**Type filter values**: `Issue`, `MergeRequest`, `Commit`, `Epic`, `DesignManagement::Design`, `AlertManagement::Alert`, `Project`, `Namespace`, `Vulnerability`, `WikiPage::Meta`

Examples:

```bash
# All pending TODOs
scripts/list-todos.sh

# Only review requests
scripts/list-todos.sh --action review_requested

# Only done MergeRequest TODOs
scripts/list-todos.sh --state done --type MergeRequest
```

### Mark a Single TODO as Done

```bash
scripts/mark-todo-done.sh <todo_id>
```

The `todo_id` is shown in `list-todos.sh` output as `(id:NNN)`.

## Award Emoji (Reactions)

Add a reaction to a note (comment) on an MR:

```bash
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<mr_iid>/notes/<note_id>/award_emoji" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name": "<emoji_name>"}'
```

Add a reaction to an MR itself:

```bash
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<mr_iid>/award_emoji" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name": "<emoji_name>"}'
```

Common project IDs: `278964` (gitlab-org/gitlab), `46519181` (gitlab-org/editor-extensions/gitlab-lsp), `34675721` (gitlab-org/cli).

## Merge Trains

### List active merge train entries

```bash
curl -s "https://gitlab.com/api/v4/projects/<project_id>/merge_trains?per_page=10" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | {merge_request: .merge_request.iid, status}'
```

### Add MR to merge train

```bash
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/merge_trains/merge_requests/<mr_iid>" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"when_pipeline_succeeds": true}'
```

**Note**: `glab mr merge --auto-merge` returns 405 for projects with merge trains enabled. Use this API instead.

## Pipelines

### List MR pipelines

```bash
curl -s "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<mr_iid>/pipelines?per_page=5" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | {id, status, source, ref}'
```

Merge train pipelines have `ref: "refs/merge-requests/<iid>/train"`.

### List failed jobs in a pipeline

```bash
curl -s "https://gitlab.com/api/v4/projects/<project_id>/pipelines/<pipeline_id>/jobs?per_page=100" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | select(.status == "failed") | {id, name, stage, web_url}'
```

### Retry a pipeline

```bash
curl -s --request POST "https://gitlab.com/api/v4/projects/<project_id>/pipelines/<pipeline_id>/retry" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '{id, status, ref}'
```

## API Documentation

For exploring GitLab API endpoints and parameters, check the local GDK docs at `/Users/tomas/workspace/gl/gdk/gitlab/doc/api/`. These are the source `.md` files for the official GitLab API docs and are useful for looking up request/response formats, required fields, and edge cases.


