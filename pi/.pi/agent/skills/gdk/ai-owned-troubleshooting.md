## Transient zeitwerk autoload error after `gdk update` / restart

The first request after a `gdk update` + `rails-web` restart can 500 with a
zeitwerk autoload error (e.g. `uninitialized constant
Gitlab::EmailHandler::ReplyKey`). It's a boot-order artifact, not real breakage —
run `mise exec -- gdk restart rails-web` and retry.

## Duo Workflow WebSocket rejected with 403 (origin not allowed)

The Duo Workflow WebSocket (`/api/v4/ai/duo_workflows/ws`) can be rejected with
`403` (`request origin not allowed by Upgrader.CheckOrigin`). The client sets
`Origin` to the GitLab instance URL, but GDK's http-router (`workerd` on :3000)
rewrites `Host` to `gdk.test:8080` before workhorse, so gorilla's default
same-origin `CheckOrigin` fails. A prebuilt workhorse tolerates it; a
source-built workhorse enforces the default. Fix: disable the GDK http-router
so nginx serves :3000 directly and `Host` matches `Origin`.

## CLI auth token: env var is `GITLAB_TOKEN`, not `GITLAB_AUTH_TOKEN`

When running the Duo CLI against GDK, pass the GDK token via `GITLAB_TOKEN`
(the CLI credential provider reads `GITLAB_TOKEN` / `--gitlab-auth-token`). A
stale `GITLAB_TOKEN` pointing at gitlab.com in the shell will be preferred and
fail with `invalid_token` against gdk.test — override it explicitly:
`GITLAB_TOKEN=$GDK_TOKEN GITLAB_BASE_URL=http://gdk.test:3000 duo run …`.


## Every `/api/v4/*` request 500s with `wrong number of arguments (given 1, expected 0)`

A `rails-web` puma that has been up for ~2 weeks while the `gitlab` checkout /
gems moved underneath it serves a stale Grape API stack — *all* API requests
(even unauthenticated `GET /api/v4/projects`) return a Rails exception page with
`wrong number of arguments (given 1, expected 0)` and nothing is written to
`gitlab/log/api_json.log`. Fix: `mise exec -- gdk restart rails-web`
(takes ~40s to boot), then re-check `curl -s -o /dev/null -w '%{http_code}'
http://gdk.test:3000/api/v4/projects`.

## Running the Duo CLI (gitlab-lsp) under tmux

Three traps, all of which make the tmux session die instantly with
`no server running`:

1. `node` inside tmux resolves to a non-mise node that rejects
   `--use-system-ca`. Use the absolute path
   (`/Users/tomas/.local/share/mise/installs/node/24/bin/node`).
1. Piping the CLI into `tee` removes the TTY, so the TUI paints once and exits.
   Never pipe; read the CLI's own log file instead
   (`$TMPDIR/gitlab-duo-cli/duo-cli-log-*.log`, or `duo log tail -f`).
1. `tmux new-session -e GITLAB_TOKEN=…` did not reach the CLI reliably; the
   token also must not carry a trailing newline (`$(cat file)` breaks the auth
   header). Prefer explicit flags in a small launcher script:
   `--gitlab-base-url http://gdk.test:3000 --gitlab-auth-token "$(tr -d '\n' < /tmp/gdk-token)"`.

If `$GDK_TOKEN` from `~/.secrets/gdk` is expired, mint a new PAT (do **not**
call `t.set_token(...)`, it breaks auth on this version — let GitLab generate it):

```bash
cd /Users/tomas/workspace/gl/gdk/gitlab && mise exec -- bundle exec rails runner '
u = User.find_by_username("root")
t = u.personal_access_tokens.create!(scopes: ["api","read_user"], name: "local-#{Time.now.to_i}", expires_at: 90.days.from_now)
puts "TOKEN=#{t.token}"'
```

## Duo Agent Platform "not available for this namespace or project" (AgenticChatForbiddenError)

Fresh GDK has no Duo add-on/entitlement, so `duo run` / the Duo CLI fail at
workflow creation with `AgenticChatForbiddenError`. Enable it once (rake tasks
need the AI Gateway URL in env):

```bash
cd /Users/tomas/workspace/gl/gdk/gitlab
AI_GATEWAY_URL="http://gdk.test:5052" mise exec -- bundle exec rake "gitlab:duo:setup[duo_enterprise]"
AI_GATEWAY_URL="http://gdk.test:5052" mise exec -- bundle exec rake gitlab:duo:onboard_dap
# diagnose a specific project:
AI_GATEWAY_URL="http://gdk.test:5052" mise exec -- bundle exec rake "gitlab:duo:verify_setup[gitlab-duo/test]"
```

`setup` seeds/entitles the `gitlab-duo` group + project and assigns root a seat;
`onboard_dap` registers the Agent Platform service accounts/flows. After this the
seeded project `gitlab-duo/test` works.

## Duo CLI resolves the namespace but not the project → 403 on workflow create

Running the CLI in a repo whose remote is on GDK, project auto-detection can
resolve only the *namespace* (`namespace_id: gitlab-duo`, no `project_id`). A
non-chat flow (`developer/v1`, `software_development`, custom inline flow) then
403s at create because `check_duo_workflow_access` needs a project container.
Pass the project explicitly: `--gitlab-project-path gitlab-duo/test`.
