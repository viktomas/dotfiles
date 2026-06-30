---
name: gitlab-api
description: Interact with GitLab REST API using GITLAB_TOKEN - use for TODOs, repositories, CI/pipelines, MRs, issues, and other API queries
---

# GitLab API

Prefer `glab` CLI commands over raw `curl`. Use `glab api` for endpoints without a dedicated subcommand. Fall back to `curl` only when `glab` doesn't work (documented below).

**NEVER write a Python/`urllib`/`requests` script (or any other ad-hoc HTTP client) to call the GitLab API.** The order is always: dedicated `glab` subcommand → `glab api` → `curl`. If you're tempted to script the API, the right command almost certainly exists below — check the update section for assignees/labels/milestones.

**Content standards** (titles, description format, the `:robot: AI-generated` prefix, and the `[title](URL)` rule for referring to MRs/issues) live in the **mr-issue-standards** skill. This skill only covers the API mechanics — read mr-issue-standards before writing any MR/issue/comment body.

**Comment/note CRUD** on MR diff lines and threads is owned by the **gitlab-mr-comments** skill (`glab mr note`). Use the curl/GraphQL fallbacks here only for what `glab mr note` can't do (award emoji, group-level work-item notes).

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

Use the `wait-for` skill's `wait-for-pipeline.sh` script — it auto-detects the current branch's pipeline, polls with early failure detection, and outputs structured JSON on failure. See the wait-for skill for full docs.

```bash
# Auto-detect pipeline from current branch (run from wait-for skill dir)
./scripts/wait-for-pipeline.sh

# Explicit pipeline ID
./scripts/wait-for-pipeline.sh <pipeline_id>
```

For manual one-off checks without the script:

```bash
# Check if any required job has already failed (pipeline is doomed)
glab api "projects/:id/pipelines/<pipeline_id>/jobs?per_page=100" \
  | jq -e '[.[] | select(.status == "failed" and .allow_failure == false)] | length > 0'
```

## glab — Issues

### Create an issue

```bash
glab issue create --title "..." --description ":robot: AI-generated

Issue body here..." -R OWNER/REPO
```

For the title style, `## Problem`/`## Solution` structure, and the `:robot:` prefix, see the **mr-issue-standards** skill.

### Update an issue — assignees, labels, milestone

Use `glab issue update`. Do **not** script the API for these.

```bash
glab issue update <iid> --assignee viktomas              # replace assignees
glab issue update <iid> --assignee @me                   # assign yourself
glab issue update <iid> --assignee +alice --assignee -bob # add alice, remove bob
glab issue update <iid> --unassign                       # remove all assignees
glab issue update <iid> --label ui,ux                    # add labels (comma-separated)
glab issue update <iid> --unlabel working                # remove labels
glab issue update <iid> --milestone "16.5"               # set milestone ('' or 0 to clear)
```

Scoped labels work as-is: `--label "type::feature"`. Add `-R OWNER/REPO` when not inside the project's worktree.

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

### Update an MR — assignees, labels, milestone, reviewers

Use `glab mr update`. Do **not** script the API for these. Works on cross-fork MRs too —
target the project where the MR lives (the upstream), e.g.
`glab mr update 3552 -R gitlab-org/editor-extensions/gitlab-lsp --label "type::feature"`.

```bash
glab mr update <iid> --assignee viktomas                 # replace assignees
glab mr update <iid> --assignee @me                      # assign yourself
glab mr update <iid> --assignee +alice --assignee -bob   # add alice, remove bob
glab mr update <iid> --unassign                          # remove all assignees
glab mr update <iid> --reviewer alice                    # request review (same +/-/! prefixes)
glab mr update <iid> --label "type::feature","group::editor extensions"  # add labels
glab mr update <iid> --unlabel "workflow::in dev"        # remove labels
glab mr update <iid> --milestone "16.5"                  # set milestone ('' or 0 to clear)
```

### Create an MR (incl. cross-fork)

```bash
glab mr create --fill --draft --target-branch main -R OWNER/REPO
```

**⚠️ Cross-fork limitation:** `glab mr create` fails with `source_branch: does not exist`
when the source branch lives in a fork and you pass the upstream as `-R`. Use the
`glab api` fallback below (POST to the **fork's** project ID with `target_project_id` set
to the upstream). Then set labels/assignee with `glab mr update` — never Python.

```bash
# Cross-fork draft MR: source in fork (56477207) -> upstream main (46519181)
glab api -X POST "projects/<fork_id>/merge_requests" \
  -f source_branch="my-branch" \
  -f target_branch="main" \
  -F target_project_id=<upstream_id> \
  -f title="Draft: feat(scope): ..." \
  -f description="$(cat /tmp/mr_description.md)" \
  -F remove_source_branch=true -F squash=true
```

Quick-action lines in the description (`/label`, `/assign`) are unreliable on cross-fork
API create — `/assign me` may apply but `/label` often doesn't. Set them explicitly with
`glab mr update` afterwards.

### Upload a file (GIF/image/attachment) and embed it in a description/comment

To put an image or GIF inside an MR/issue description or comment, first upload it to the
project's uploads store, then use the returned markdown snippet. The `--form file=@PATH`
syntax streams the binary correctly — do **not** script this with Python.

```bash
glab api --method POST projects/:id/uploads --form "file=@/tmp/demo.gif" \
  | jq -r '.markdown'
# -> ![demo](/uploads/<hash>/demo.gif)
```

Paste that `![...](...)` markdown into the `--description` body (or a note) and update the
MR/issue. Run from the project worktree so `:id` resolves; otherwise use the numeric
project ID (e.g. `projects/46519181/uploads`). The upload is scoped to that project, so
embed it in an MR/issue of the **same** project.

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

Uses helper scripts in `./scripts/`.

### List TODOs

```bash
./scripts/list-todos.sh [--state pending|done] [--action ACTION] [--type TYPE] [--per-page N]
```

Defaults to `--state pending --per-page 50`.

**Action filter values**: `assigned`, `mentioned`, `build_failed`, `marked`, `approval_required`, `unmergeable`, `directly_addressed`, `merge_train_removed`, `review_requested`, `member_access_requested`

**Type filter values**: `Issue`, `MergeRequest`, `Commit`, `Epic`, `DesignManagement::Design`, `AlertManagement::Alert`, `Project`, `Namespace`, `Vulnerability`, `WikiPage::Meta`

```bash
./scripts/list-todos.sh                                    # all pending
./scripts/list-todos.sh --action review_requested          # only review requests
./scripts/list-todos.sh --state done --type MergeRequest   # done MR TODOs
```

### Mark a Single TODO as Done

```bash
./scripts/mark-todo-done.sh <todo_id>
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

## GraphQL — Work Items (Epics, Issues)

Group-level work items (new-style epics) have **no REST API for notes**, so `glab mr note` / the **gitlab-mr-comments** skill can't reach them. Use GraphQL here instead.

### Fetch work item comments (non-system notes)

**⚠️ Always use `filter: ONLY_COMMENTS`** on the `discussions` field. Without it, the default page is flooded with system notes (label changes, child additions, etc.) and real comments won't appear.

```graphql
{
  group(fullPath: "gitlab-org") {
    workItem(iid: "19717") {
      title
      widgets {
        ... on WorkItemWidgetNotes {
          type
          discussions(filter: ONLY_COMMENTS) {
            nodes {
              notes {
                nodes {
                  id
                  body
                  author { username }
                  createdAt
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Fetch work item children (hierarchy)

```graphql
{
  group(fullPath: "gitlab-org") {
    workItem(iid: "19717") {
      title
      widgets {
        ... on WorkItemWidgetHierarchy {
          children {
            nodes {
              iid
              title
              state
              webUrl
              workItemType { name }
            }
          }
        }
      }
    }
  }
}
```

### Fetch a single note by ID

If you have a note URL like `#note_3390005104`, fetch it directly:

```graphql
{ note(id: "gid://gitlab/Note/3390005104") { body author { username } createdAt } }
```

## API Documentation

For exploring GitLab API endpoints and parameters, check the local GDK docs at `/Users/tomas/workspace/gl/gdk/gitlab/doc/api/`. These are the source `.md` files for the official GitLab API docs.

## References

Detailed docs for niche APIs live in `references/` next to this file. Read them when the topic comes up.

| File | Topic |
|------|-------|
| `references/duo-workflows-api.md` | Duo Workflows checkpoint API — creating workflows, posting checkpoints, `ui_chat_log` shape, direct-access tokens |
