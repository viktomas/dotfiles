---
name: gitlab-api
description: CRUD GitLab issues,MRs,pipelines,jobs,epics,issue comments
---

## MR

- For MR comments, use the `gitlab-mr-comments` skill!

- Read
  - Use `glab mr view <ID if not run on branch>`  (if run on a branch, recognises the MR automatically)

### Create MR
- Write the description to a temp file, then expand it into `-d` via command substitution so multi-line/markdown content is passed intact:
  ```sh
  glab mr create -a viktomas -t "<title>" -d "$(cat /tmp/mr-desc.md)" --yes
  rm -f /tmp/mr-desc.md
  ```
- when writing the MR description, use progressive disclosure:
- first paragraph summarises why this is needed and what the MR does
- then you list references, relevant issues, always include full URLs, followed by `+` (e.g. `https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/3622+`) the `+` expands the URL in the GitLab Markdown rendering
- after references include more detailed explanation of the MR, don't copy code, explain it on a high level, mention the components and how they intract together
- then add "How has this been tested" with detailed manual testing strategy (which you already executed, don't guess there)
- all remaning details come into `<details>` section at the end

### Update MR description after creation
- Change the body (e.g. after uploading a screenshot):
  ```sh
  glab mr update <iid> -d "$(cat /tmp/mr-desc.md)"
  ```

## Embed an image (before/after screenshots, GIFs)
- Upload to the project's uploads store, then paste the returned `.markdown` into the description:
  ```sh
  curl -s -X POST "https://gitlab.com/api/v4/projects/278964/uploads" \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -F "file=@/tmp/after.png;type=image/png"
  # -> {"markdown":"![after](/uploads/<hash>/after.png)"}
  ```
- Use the numeric project id (`278964` = gitlab-org/gitlab); the upload is scoped to that project, so embed it only in that project's MR/issue.


## Issues

- Read
  - Use `glab issue view <issue numeric ID>`
