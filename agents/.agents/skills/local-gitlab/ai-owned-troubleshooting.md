# Local GitLab (Caproni) troubleshooting

Add an entry every time you debug a local-instance issue. Older entries carried over from
GDK days are marked *(from GDK)*; the Duo/CLI ones still apply, the commands are adapted.

## `mise ERROR No version is set for shim: kubectl`

This was fixed on 2026-11-10: `kubectl@1.37.2` and `helm@4.3.1` are now global in
`~/.config/mise/config.toml`. If it comes back, run `mise use -g kubectl@<version>`, using
the version from the instance's `.tool-versions`. Then use `kubectl --context caproni-a|caproni-b`.

## Instance has no users (`User.count == 0`), runner crash-loops with `403 invalid token supplied`

Seen on instance B on 2026-11-10. The migrations Job was evicted part way through (DiskPressure
during setup) and restarted. The schema got created but the production seeds never ran, so
there was no root user and no runner registration token. The web UI still returned 200.
Fix: seed by hand in the toolbox with the chart's secrets, then restart the runner:

```bash
PW=$(mise run -q gitlab:rootpassword)
RT=$(caproni kubectl -n gitlab get secret gitlab-gitlab-runner-secret -o jsonpath='{.data.runner-registration-token}' | base64 -d)
caproni kubectl -n gitlab exec deploy/gitlab-toolbox -c toolbox -- \
  env GITLAB_ROOT_PASSWORD="$PW" GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN="$RT" gitlab-rake db:seed_fu
caproni kubectl -n gitlab rollout restart deploy/gitlab-runner
```

A healthy runner log ends with `Initializing executor providers` and doesn't show `PANIC`.

## Pods evicted / `DiskPressure`

The shared Colima VM disk (100 GiB) holds every cluster's image cache plus anything else in
docker. Check with `colima ssh -- df -h /var/lib/docker`. Free space with
`docker image prune -a` and only with Tomas's OK, because it removes his local build images.
Then delete the `Evicted`/`Failed` pods: `caproni kubectl delete pod -A --field-selector=status.phase=Failed`.

## kubectl `host is down` / connection refused after the laptop sleeps

The Colima VM network went stale. Run `colima restart` (profile `default`; the upstream
docs say `--profile caproni`, but not here). This restarts **both** instances. Then run
`caproni status` in each dir and `caproni up` if needed, one at a time.

## Interrupted `caproni up` → `another operation (install/upgrade/rollback) is in progress`

See the `caproni` skill in `~/workspace/gl/gitlab-caproni/skills/caproni/SKILL.md`. In short:
kill the orphan helm process (`pgrep -fl 'helm (install|upgrade)'`), roll back a
`pending-upgrade` or uninstall a `pending-install` (never the `gitlab` or `gitlab-dev-stack`
releases), then rerun `caproni up` in the background.

## Instance B redirects to port 80 (instance A)

This is by design: the GitLab chart has no external-port setting. Use A for browser
flows, or switch B to a per-VM colima driver (its own IP, no port shifting).

## glab: `tls: failed to verify certificate` against a caproni host

glab defaults to https. There are two fixes:
`glab config set --host <host[:port]> api_protocol http`, and trusting the cluster CAs in the
keychain with `caproni-trust` (sudo, see SKILL.md "TLS / certificates"). After a cluster is
recreated its CA changes, so run `caproni-trust` again.

## CLI auth token: env var is `GITLAB_TOKEN`, not `GITLAB_AUTH_TOKEN` *(from GDK)*

The Duo CLI reads `GITLAB_TOKEN` or `--gitlab-auth-token`. If your shell has a gitlab.com
`GITLAB_TOKEN`, the CLI uses it and fails with `invalid_token`. Override it explicitly:
`GITLAB_TOKEN=$CAPRONI_A_TOKEN GITLAB_BASE_URL=$CAPRONI_A_URL duo run …`.

## Running the Duo CLI (gitlab-lsp) under tmux *(from GDK)*

Three traps make the tmux session die instantly with `no server running`:

1. Inside tmux, `node` resolves to a non-mise node that rejects `--use-system-ca`. Use the
   absolute path `/Users/tomas/.local/share/mise/installs/node/24/bin/node`.
1. Piping the CLI into `tee` removes the TTY, so the TUI paints once and exits. Don't pipe.
   Read the CLI's own log instead (`$TMPDIR/gitlab-duo-cli/duo-cli-log-*.log` or `duo log tail -f`).
1. `tmux new-session -e GITLAB_TOKEN=…` doesn't reliably reach the CLI, and a token with a
   trailing newline breaks the auth header. Use explicit flags in a small launcher script:
   `--gitlab-base-url $CAPRONI_A_URL --gitlab-auth-token "$CAPRONI_A_TOKEN"`.

## Duo Agent Platform "not available for this namespace or project" (AgenticChatForbiddenError) *(from GDK)*

The instance has no Duo add-on or entitlement. On Caproni, the AI Gateway fragment's first
`caproni run` seeds this (see SKILL.md). By hand, in edit mode from `repos/gitlab`:

```bash
.gitlab/caproni/exec.sh bundle exec rake "gitlab:duo:setup[duo_enterprise]"
.gitlab/caproni/exec.sh bundle exec rake gitlab:duo:onboard_dap
.gitlab/caproni/exec.sh bundle exec rake "gitlab:duo:verify_setup[gitlab-duo/test]"
```

(GDK needed `AI_GATEWAY_URL` in the env for these. On Caproni, check what the lifecycle hook
sets before adding it.)

## Duo CLI resolves the namespace but not the project → 403 on workflow create *(from GDK)*

In a repo whose remote points at the local instance, project auto-detection can return only
the namespace. Non-chat flows then 403 because `check_duo_workflow_access` needs a project.
Pass the project explicitly with `--gitlab-project-path gitlab-duo/test`.

## Duo CLI per-user settings (e.g. `autoMode`) live in `~/.gitlab/storage.json` *(from GDK)*

They're keyed `gid://gitlab/User/<id>:Duo CLI:<setting>` with a `{"enabled": bool}` value.
Root on a local instance is `User/1`, so toggling a setting there doesn't touch the
gitlab.com profile's entry.

## Duo CLI auto-mode state (gitlab-lsp !4008/!4010, epic &23199) *(from GDK)*

`duo_auto_mode` came from the unmerged gitlab!253317, so you need edit mode with that branch
in `repos/gitlab`. Then run, through `.gitlab/caproni/exec.sh bundle exec rails runner`:

```ruby
Feature.enable(:duo_workflow_local_tool_governance)
a = ApplicationSetting.current
a.update!(tool_approval_for_session_enabled: true, duo_auto_mode_enabled: true,
          lock_tool_approval_for_session_enabled: false, lock_duo_auto_mode_enabled: false)
ns = Group.find_by_full_path("gitlab-duo").namespace_settings
ns.update!(tool_approval_for_session_enabled: true, duo_auto_mode_enabled: true,
           lock_tool_approval_for_session_enabled: false, lock_duo_auto_mode_enabled: false)
Project.find_by_full_path("gitlab-duo/test").project_setting.update!(duo_auto_mode_enabled: true)
```

The availability accessors are tri-state (`default_on`/`default_off`/`never_on`).
`locked: true` normalizes to `never_on` and **disables** the capability even with
`enabled: true`. To verify, query `aiFlowsMetadata(namespaceId:, projectId:) { capabilities { name } }`
over `/api/graphql` and expect `duo_auto_mode`. A deny `Ai::ToolRule` is enforced by DWS
removing the tool from the toolset, so the agent says the tool "is not available" instead of
showing a denial.

## CI pipeline/job stuck in `created`, runner online but never dispatched *(from GDK)*

`Ci::InitialPipelineProcessWorker` never ran or failed. On Caproni in edit mode the usual
cause is Puma in edit mode **without** Sidekiq (`edit_reloaders: [gitlab, sidekiq]`). In
cluster mode, check the sidekiq pod logs (`caproni kubectl -n gitlab logs deploy/gitlab-sidekiq-all-in-1-v2`).
After fixing it, re-enqueue the pipeline:
`gitlab-rails runner -e production 'Ci::InitialPipelineProcessWorker.perform_async(<pipeline_id>)'`
in the toolbox. If the pipeline sat for a long time, short-lived OAuth tokens in its CI vars
may have expired (`WebSocket upgrade rejected with HTTP 401`). Start a fresh workflow
instead of reusing it.

## `caproni run` in tmux: hook fails with `uninitialized constant Gem::Resolver::APISet::GemParser`

Seen 2026-11-10 on A. The stack trace mixes mise's bundler with `/System/Library/.../ruby/2.6`:
a tmux session started with `bash -lc` doesn't get the mise PATH, so the edit-mode hooks
(`db_migrate.sh` → `bundle exec rake db:migrate`) hit macOS system ruby. Launch `caproni run`
from a small script that exports your current `PATH` (and `ANTHROPIC_API_KEY`,
`CAPRONI_ACTIVATE_LICENSE=1`) before calling it. The `op signin` prompt that the license step
shows times out ("authorization prompt dismissed") when nobody approves it, so Tomas must be
at the desk for the first `caproni run` with the AI Gateway fragment.

## Running a Duo remote flow (DAP session) on A in edit mode — 2026-11-10 checklist

What it took to get a `@duo-developer-gitlab-duo` mention to complete on instance A with a
monolith branch in `repos/gitlab` and the AI Gateway fragment:

- **License lives in two DBs.** The stock pods use `gitlabhq_production`, edit mode uses
  `gitlabhq_development`. A license activated in the UI before `caproni run` lands in production
  only. Copy it: dump `License.last.data` in the toolbox (`-e production`), then
  `License.create!(data: …)` through `.gitlab/caproni/exec.sh bundle exec rails runner`.
  After that, run with `CAPRONI_ACTIVATE_LICENSE=0`, so `op` doesn't prompt.
- **Two edit-mode instances share host ports.** If another agent runs `caproni run` on B, Vite's
  3036 is taken. Export `VITE_RUBY_PORT=3037` for A.
- **DWS waits for `gitlab.caproni.test`.** `wait-for-gitlab.sh` uses `CAPRONI_PRIMARY_HOSTNAME`,
  which the reloader process doesn't get. Export `CAPRONI_PRIMARY_HOSTNAME=gitlab.a.caproni.test`
  before `caproni run`.
- **In-cluster DNS doesn't resolve `gitlab.a.caproni.test`, and pods have no IPv6 egress.** The
  `kube-system/coredns-custom` ConfigMap on A now has
  `rewrite name exact gitlab.a.caproni.test traefik.kube-system.svc.cluster.local` and an
  `anthropic.com` server block that answers AAAA with an empty NOERROR. Without the second part,
  DWS under mirrord picks Anthropic's IPv6 address and fails with `anthropic.APIConnectionError`
  (the mirrord intproxy log shows `NetworkUnreachable … [2607:6bc0::10]:443`). Restart CoreDNS
  after you edit the ConfigMap.
- **Stock Workhorse (chart image) is older than master Rails.** Two skews broke DAP on
  19.5.3 Workhorse with 19.6 Rails: (1) Rails `verify_api_request!` requires `iat`, but old
  Workhorse duoworkflow actions don't send it (`JWT::InvalidIatError` / 403 on `…/authorize`).
  (2) Rails passes the agent token as `GitlabToken`, but old Workhorse reads
  `Service.Headers["x-gitlab-oauth-token"]`. DWS's GraphQL is then anonymous, so you see
  `No workflow found for workflow ID: N` and 401s on `audit_events`. For a test run, patch both
  locally (drop `iat_after` in `lib/gitlab/workhorse.rb#verify_api_request!`, and merge
  `'x-gitlab-oauth-token' => gitlab_token` into `grpc_headers`). Revert them afterwards. The real
  fix is a matching Workhorse (bump the chart image or run Workhorse from the checkout).
- **Runner privileged.** A's `caproni.local.yaml` sets `privileged = true` in the runner TOML.
  With it, `SRT sandbox test successful` shows up for custom images that install bubblewrap and srt.
- **Stopping `caproni run`.** Send `C-c` to it (tmux send-keys) and don't pipe it through `tee`.
  `tmux kill-session` or a dead `tee` leaves the `*-caproni` copy deployments and local Vite
  processes behind. Then you have to `kubectl delete deploy <x>-caproni` and kill the orphans,
  and wait for the originals to roll out before the next `caproni run`. Otherwise `setup.sh`
  fails with `No Running webservice pod`.
- Launcher and restart scripts: `/tmp/caproni-a-run.sh` and `/tmp/caproni-a-restart.sh`
  (they're ephemeral and export PATH, the env vars above and `ANTHROPIC_API_KEY`).
- glab `api -X POST …/repository/files` returns 403 through Workhorse in this state. Use `git push`.
