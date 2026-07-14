---
name: gdk
description: GitLab Development Kit is a folder and set of utilities that contain most of the GitLab production systems. This skill is useful for testing with local GitLab deployment and when researching how feature works in the GitLab monolith, AIGW, workhorse and other services
---

GDK lives in /Users/tomas/workspace/gl/gdk

## Subfolders

- `gitlab` contains the main GitLab monolith Ruby on Rails codebase, database, API, frontend, everything
- `gitlab-ai-gateway` AI Gateway (AIGW) and Duo Workflow Service (DWS)

## Running `gdk`

`gdk` is **not on PATH**. Run it via mise from the gdk dir:
`cd /Users/tomas/workspace/gl/gdk && mise exec -- gdk <cmd>`

## Starting GDK

Start GDK with `cd /Users/tomas/workspace/gl/gdk && mise exec -- gdk start`

## Updating GDK

Update GDK with `cd /Users/tomas/workspace/gl/gdk && mise exec -- gdk update`

This will checkout the default branches so make sure that all work in progress is comitted.

**`gdk update` is slow (~10-15 min).** It git-pulls every component, runs
`bundle install` + `yarn install`, downloads prebuilt gitaly + workhorse
binaries (network-bound), and runs DB migrations. Don't run it as a blocking
foreground call — it will hit tool timeouts. Instead run it in the background
and poll the log:

```bash
cd /Users/tomas/workspace/gl/gdk
nohup mise exec -- gdk update > /tmp/gdk-update.log 2>&1 &
# then poll: tail -8 /tmp/gdk-update.log ; ps -p <pid>
```

Progress markers in the log, in order: tool-versions → bundle/yarn install →
DB setup/migrations → `Package extracted successfully` (workhorse, then
gitaly) → `Successfully updated in Xm Ys!` at the end.

Thanks to complications like migrations, you want to generally rebase your WIP branches on latest main/master after upgrading GDK

## Auth

```
cat ~/.secrets/gdk
export GDK_TOKEN=glpat-xxx
export GDK_RUNNER_TOKEN="glrt-yyy"
```

this file is sourced and the env variables available to you

## Duo test project

Seeded Duo test project at `/Users/tomas/workspace/test/test` (remote `http://gdk.test:3000/gitlab-duo/test.git`). Use as cwd when running the Duo CLI (avoids some edge cases).

## Troubleshooting

For issues, look into [AI-owned troubleshooting docs](./ai-owned-troubleshooting.md). Update this file every time after you debug a gdk issue.
