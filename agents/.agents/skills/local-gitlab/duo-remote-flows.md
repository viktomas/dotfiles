# Duo remote flows (DAP sessions) on Caproni

How to run a flow such as developer/v1 end to end: mention a flow service account on an issue,
and a CI workload job runs `duo run` against local DWS and AIGW. Verified on instance A on
2026-11-10 with MR !268004 (state in
`~/workspace/gl/work/tasks/state/retest-mr-skills-fix.md`).

## What instance A already has (as of 2026-11-10)

- `caproni.local.yaml`: the `ai-gateway` fragment, edit reloaders `[gitlab, sidekiq]` + `[ai-gateway]`,
  and a runner `dynamic_overrides` entry that sets **`privileged = true`** in the runner TOML
  (plus tags `gitlab--duo`, `runUntagged`). The fragment's own runner override is
  appended, not replaced (`caproni config print` to verify).
- `kube-system/coredns-custom` ConfigMap (applied by hand, survives `caproni up`, not `destroy`):
  ```yaml
  data:
    gitlab-host.override: |
      rewrite name exact gitlab.a.caproni.test traefik.kube-system.svc.cluster.local
    no-aaaa-anthropic.server: |
      anthropic.com:53 {
        template IN AAAA anthropic.com {
          rcode NOERROR
        }
        forward . /etc/resolv.conf
      }
  ```
  - The rewrite: DWS (under mirrord, which uses the ai-gateway pod's DNS) must reach
    `http://gitlab.a.caproni.test` on port 80 inside the cluster. Without it, DWS
    never starts.
  - The AAAA block: pods have no IPv6 egress, but httpx picks Anthropic's IPv6 address and fails
    with `anthropic.APIConnectionError: Connection error.` The mirrord intproxy log in
    `$TMPDIR/mirrord-intproxy-*.log` shows `NetworkUnreachable … [2607:6bc0::10]:443`.
  - After editing, run `kubectl --context caproni-a -n kube-system rollout restart deploy coredns`.
    Instance B needs the same with its own hostname.
- Seeded by the ai-gateway setup hook in the dev DB: group `gitlab-duo` (foundational flows on),
  project `gitlab-duo/test`, the 17 catalog flows, and service accounts such as
  `duo-developer-gitlab-duo`. The setup is skipped once
  `repos/ai-gateway/.caproni-duo-setup-complete` exists. Rerun it with `CAPRONI_DUO_SETUP_FORCE=1`.
- Test projects: `gitlab-duo/skills-retest` (id 1, custom image `node:22-slim` + srt) and
  `gitlab-duo/skills-default` (id 2, default image), each with issue 1.

## Run a session

1. Edit mode up: `scripts/caproni-run.sh a` (see [edit-mode.md](./edit-mode.md)). The license must
   be in the **dev** DB.
2. If the branch is ahead of the chart's Workhorse, apply the skew patch (next section).
3. For a new project, the flow service accounts aren't members. Sync them through `exec.sh`:
   ```ruby
   p = Project.find_by_full_path('gitlab-duo/<new>'); ids = Ai::Catalog::Item.pluck(:id)
   p.sync_enabled_foundational_flows!(ids)
   Ai::Catalog::Flows::SyncFoundationalFlowsService.new(p, current_user: User.admins.first).execute
   ```
   Add files with `git push` (`http://root:$CAPRONI_A_TOKEN@gitlab.a.caproni.test/<path>.git`).
   With the skew, the files API fails (403 on `/authorize`).
4. Trigger and wait:
   ```bash
   scripts/dap-mention.sh a gitlab-duo/skills-retest 1 duo-developer-gitlab-duo "Without using any tools, reply OK."
   ```
   It prints the job status, saves the ANSI-stripped log to `/tmp/dap-job-a-<id>.txt` and shows
   the agent's reply note. "Something went wrong" or `failed (dropped)` notes mean that DWS
   or Rails failed. Read the logs listed below.

## Stock Workhorse vs branch Rails

Instance A runs chart image **v19.5.3**. Master/branch Rails 19.6 changed two Workhorse
contracts, and DAP breaks in a misleading way:

| Change in Rails | Old Workhorse does | You see |
|---|---|---|
| `verify_api_request!` requires an `iat` claim | duoworkflow HTTP actions sign without `iat` | `JWT::InvalidIatError` in `log/exceptions_json.log`, 403 on `…/authorize` (files API too) |
| agent token moved to `GitlabToken` in the ws config | reads `Service.Headers["x-gitlab-oauth-token"]` | DWS GraphQL runs anonymously: `No workflow found for workflow ID: N`, 401 on `…/workflows/N/audit_events`, websocket closed `4400` |

Local-only fix. Apply it before testing and revert it before you commit or push:

```bash
cd ~/workspace/gl/caproni-agent-a/repos/gitlab
git apply ~/.agents/skills/local-gitlab/patches/stock-workhorse-dap-skew.patch     # then caproni-stop/run (lib/ change)
git apply -R ~/.agents/skills/local-gitlab/patches/stock-workhorse-dap-skew.patch  # afterwards
```

Once the chart image catches up to the branch, you don't need the patch. Check
`git apply --check` first. If it no longer applies, the code moved: re-derive it from the two
rows above.

## What a healthy sandboxed run looks like (job log)

- `Downloading duo-cli <ver> (duo-linux-arm64)...` (custom image without `duo`) or
  `duo-cli already present` (the default image ships its own; `v0.0.26` had 10.0.0).
- `SRT sandbox test successful, running command: duo run …`. This needs srt and bubblewrap in the
  image **and** a privileged runner. The default image hit
  `SRT found but can't create sandbox (insufficient privileges), running command directly`
  even with privileged.
- Then `$SANDBOX_UNSHARE env -i VAR="$VAR" … srt … duo run`. Every `base_variables` entry from
  `StartWorkflowService` shows up there as `NAME="$NAME"`.
- Inside the sandbox, `$HOME` is read-only, so `EROFS … mkdir '/root/.gitlab/…'` warnings are normal.

Minimal custom image for the sandbox (`.gitlab/duo/agent-config.yml`):

```yaml
image: node:22-slim
setup_script:
  - apt-get update && apt-get install -y --no-install-recommends curl ca-certificates git bubblewrap socat ripgrep
  - npm install -g @anthropic-ai/sandbox-runtime@0.0.20
```

## Seeing what the model got (no LangSmith key here)

- **Client side, no setup:** `duo run` logs its `startRequest` in the job log at debug level.
  The `additional_context` entries are there verbatim, for example the agent-skills block
  `"content": "The following agent skills are available…"`. Decode that line with `json.loads`.
- **Server side:** DWS runs from `repos/ai-gateway` locally. Add a temporary dump where
  the context is consumed, for example in `duo_workflow_service/agent_platform/v1/flows/base.py`
  `_process_additional_context` (id `agent-skills-instructions` → `workspace_agent_skills`),
  and write `item.content` to `/tmp/…`. Restart with stop/run, and revert afterwards.
- LangSmith needs `LANGCHAIN_TRACING_V2=true` + `LANGCHAIN_API_KEY`/`LANGCHAIN_PROJECT` in
  `repos/ai-gateway/.env`. Tomas has no key on this machine, so ask him.

## Where to look when a session fails

| What | Where |
|---|---|
| Rails (edit mode) | `repos/gitlab/log/{api_json,exceptions_json,application_json,graphql_json}.log`. Grep for the correlation id from the DWS log |
| DWS / AIGW | `[duo-workflow-service]` / `[ai-gateway]` lines in `/tmp/caproni-run-a.log` |
| mirrord networking | `$TMPDIR/mirrord-intproxy-*.log` (newest), `WARN` lines |
| Runner | `kubectl --context caproni-a -n gitlab logs deploy/gitlab-runner`. A runner pod in CrashLoopBackOff after edit-mode restarts recovers with `kubectl delete pod` |
| Job | `scripts/dap-mention.sh` output log, or `GET /projects/:id/jobs/:id/trace` |
