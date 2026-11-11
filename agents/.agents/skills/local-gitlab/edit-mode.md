# Edit mode: run a branch's code on a Caproni instance

Read this before running `caproni run`. Its traps cost about an hour on 2026-11-10.

## Set up (once per branch)

1. Check out the branch at `<instance>/repos/gitlab`. A worktree of the bare monolith repo
   works and needs no extra clone:
   ```bash
   git -C ~/workspace/gl/gitlab/.bare fetch origin <branch>
   git -C ~/workspace/gl/gitlab/.bare worktree add --track -b <branch> \
     ~/workspace/gl/caproni-agent-a/repos/gitlab origin/<branch>
   ```
   The setup hooks then modify `db/structure.sql` and `.labkit_logging_todo.yml` in that
   worktree. **Never commit them.**
2. In `caproni.local.yaml`, add `repositories: { gitlab: { edit_reloaders: [gitlab, sidekiq] } }`.
   Always include sidekiq, or CI jobs stay in `created`. Run `caproni config print`
   to see the merged result. Lists like `dynamic_overrides` are **appended** across files, not replaced.
3. Run `caproni up` in the background (see SKILL.md, Lifecycle).

## Start / stop: use the scripts, not raw `caproni run`

```bash
~/.agents/skills/local-gitlab/scripts/caproni-run.sh a     # tmux caproni-a-run, log /tmp/caproni-run-a.log
~/.agents/skills/local-gitlab/scripts/caproni-stop.sh a    # back to stock mode, cleaned up
```

`caproni-run.sh` waits until `/api/v4/user` returns 200 (and DWS listens, when the
ai-gateway reloader is configured), which takes about 90 s warm. It also works around these traps:

| Trap | Symptom | Workaround in the script |
|---|---|---|
| tmux shells lack the mise PATH | hook crash `uninitialized constant Gem::Resolver::APISet::GemParser` (system ruby 2.6) | writes a launcher that exports your PATH |
| B (or another agent) in edit mode too | `[vite] Error: Port 3036 is already in use`, reloader exits | `VITE_RUBY_PORT` 3037/3038/3039 per instance |
| DWS waits for `gitlab.caproni.test` | `Timed out waiting for GitLab OIDC endpoint` | exports `CAPRONI_PRIMARY_HOSTNAME=gitlab.<x>.caproni.test` |
| `caproni run \| tee` | when tee dies, caproni dies without cleanup | logs by redirect, no pipe |
| 1Password prompt nobody answers | `authorization prompt dismissed` | `CAPRONI_ACTIVATE_LICENSE=0` (license per DB, see below) |

`caproni-stop.sh` sends C-c, then cleans up what a killed run leaves behind:

- the `*-caproni` copy deployments, which make the next run fail with
  `caproni deployments detected`
- originals scaled to 0, which make the next run's `setup.sh` fail with `No Running webservice pod found`
- orphaned local vite/mirrord/ruby processes holding ports

Even a graceful C-c can leave orphans. Never use `tmux kill-session` alone.

`caproni-run.sh` fails fast (no 15-min poll) when caproni logs `ERROR`, a reloader process is
stopped for good (`Process exited abnormally. Stopped`), DWS's OIDC wait times out, or a port is
in use. It also refuses to start when the instance's CoreDNS rewrite is missing (see
[duo-remote-flows.md](./duo-remote-flows.md)). Without that rewrite DWS never starts.

## A and B in edit mode at the same time

All edit-mode processes bind on the shared host. A keeps the defaults. B's
`caproni.local.yaml` shifts every port by +10 (verified 2026-11-10, both up together):

| Process | A (default) | B | How it's moved |
|---|---|---|---|
| puma | 8081 | 8091 | `env.INTERNAL_PORT` + mirrord `incoming.port_mapping: ["8091:8081"]` |
| puma control | 9293 | 9303 | `env.PUMA_CONTROL_PORT` |
| web exporter | 8083 | 8093 | `sed` on `config/gitlab.yml` in the puma command (no env var; setup.sh re-copies the yml each run) |
| sidekiq exporter / health | 3807 / 3808 | 3817 / 3818 | `sed` on `config/gitlab-sidekiq.yml` in the sidekiq command |
| vite | 3037 (script) | 3038 | `env.VITE_RUBY_PORT` on puma, vite and sidekiq |
| AIGW api / metrics | 5052 / 8082 | 5062 / 8092 | `env.AIGW_FASTAPI__API_PORT/METRICS_PORT` + `port_mapping: ["5062:5052", "50062:50052"]` |
| DWS grpc / metrics | 50052 / 8083 | 50062 / 8094 | `env.PORT`, `env.PROMETHEUS_METRICS__PORT` |

Local `reloaders:` deep-merge into the repo's `caproni-project.yaml` (check with
`caproni --log-color false config print`). Overriding a `command` replaces it, so B's puma and
sidekiq commands are copies of the repo's. Re-sync them when the repo's file changes. Write them as
`>-` block scalars, because `port: 8083` inside a plain scalar breaks the YAML. The copy to
start from is `~/workspace/gl/caproni-agent-b/caproni.local.yaml`. Workhorse isn't an edit
reloader, so its hardcoded `-authBackend :8081` doesn't matter.

Pass extra env after the instance, for example `caproni-run.sh a CAPRONI_ACTIVATE_LICENSE=1` or
`CAPRONI_DUO_SETUP_FORCE=1`. `ANTHROPIC_API_KEY` is taken from your env.

## Two databases

Edit mode uses **`gitlabhq_development`**. The stock pods (toolbox, and the web UI when edit
mode is off) use **`gitlabhq_production`**. Users, tokens, projects, licenses and feature flags
differ between them:

- Rails through your checkout: `cd repos/gitlab && .gitlab/caproni/exec.sh bundle exec rails runner '…'`.
  The toolbox `gitlab-rails runner -e production` sees the *other* DB.
  `exec.sh` runs in the repo checkout, so script files must live inside `repos/gitlab`
  (e.g. untracked `.gitlab-caproni-*.rb`). Paths outside it aren't visible.
- `$CAPRONI_A_TOKEN` happens to work in both (root PAT seeded in both).
- A license activated through the UI or the toolbox lands in production only. To copy it,
  dump `License.last.data` in the toolbox and `License.create!(data: …)` through `exec.sh`.
  Or run the manual script from [license-activation.md](./license-activation.md) through `exec.sh`.

## Version skew: stock chart images vs your branch

Only Puma and Sidekiq run your code. **Workhorse, Gitaly, the runner and the toolbox stay on the
chart's image version** (check it with
`kubectl --context caproni-a get deploy gitlab-webservice-default -o jsonpath='{..image}'`).
When your branch is a minor version ahead, Workhorse↔Rails protocol changes can break
features that look unrelated to your branch. Known cases are in
[duo-remote-flows.md](./duo-remote-flows.md#stock-workhorse-vs-branch-rails) (DAP and file
uploads via `…/authorize`). If you hit one, prefer a local patch you revert afterwards, or
bump the chart and image version. Don't spend time debugging the branch.

## Hot reload

App code (`app/`, `ee/app/`) reloads. Editing `lib/` can leave Puma half-reloaded
(`undefined method 'to_sym' for an instance of API::Scope`, 500s). After `lib/` changes, restart
with `caproni-stop.sh a && caproni-run.sh a`.
