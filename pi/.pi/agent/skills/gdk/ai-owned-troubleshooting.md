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

