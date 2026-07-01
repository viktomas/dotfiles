---
name: gdk
description: GitLab Development Kit is a folder and set of utilities that contain most of the GitLab production systems. This skill is useful for testing with local GitLab deployment and when researching how feature works in the GitLab monolith, AIGW, workhorse and other services
---

GDK lives in /Users/tomas/workspace/gl/gdk

## Subfolders

- `gitlab` contains the main GitLab monolith Ruby on Rails codebase, database, API, frontend, everything
- `gitlab-ai-gateway` AI Gateway (AIGW) and Duo Workflow Service (DWS)

## Starting GDK

Start GDK with `cd /Users/tomas/workspace/gl/gdk && gdk start`

## Updating GDK

Update GDK with `cd /Users/tomas/workspace/gl/gdk && gdk update`

This will checkout the default branches so make sure that all work in progress is comitted.

Thanks to complications like migrations, you want to generally rebase your WIP branches on latest main/master after upgrading GDK

## Auth

```
cat ~/.secrets/gdk
export GDK_TOKEN=glpat-xxx
export GDK_RUNNER_TOKEN="glrt-yyy"
```

this file is sourced and the env variables available to you
