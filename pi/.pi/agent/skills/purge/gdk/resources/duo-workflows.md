# Duo Workflows in GDK

## Overview

Duo Workflows run via CI workloads. The flow is:
1. API call creates a workflow + CI workload (job)
2. CI runner picks up the job, installs `@gitlab/duo-cli`, runs `duo run`
3. CLI connects to Duo Workflow Service (DWS) via websocket and streams events

## DWS Location

DWS runs from within the `gitlab-ai-gateway` repo using poetry:
- Repo: `/Users/tomas/workspace/gl/gdk/gitlab-ai-gateway/`
- Remote: `git@gitlab.com:gitlab-org/modelops/applied-ml/code-suggestions/ai-assist.git`
- Service run script: `/Users/tomas/workspace/gl/gdk/services/duo-workflow-service/run`
- Port: 50052 (gRPC)

To switch DWS to a feature branch:
```bash
cd /Users/tomas/workspace/gl/gdk/gitlab-ai-gateway
git fetch origin <branch>
git checkout FETCH_HEAD
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk restart duo-workflow-service'
```

**Remember to switch back to `main` when done.**

## Permissions Required for Workflow Creation

Creating a workflow via the API (`POST /api/v4/ai/duo_workflows/workflows`) requires ALL of:

1. **`duo_agent_platform_enabled`** (instance-level for self-managed):
   ```ruby
   Ai::Setting.instance.update!(duo_agent_platform_enabled: true)
   ```

2. **`ai_workflows` license feature** — available with Ultimate license (provisioned by GDK)

3. **Duo Enterprise add-on purchase + seat assignment** — the `allowed_to_use?(:duo_agent_platform)` check goes through `UserAuthorizable` which checks add-on purchases:
   ```ruby
   addon = GitlabSubscriptions::AddOn.find_by(name: :duo_enterprise)
   group = Group.find(96) # gitlab-duo group
   user = User.find_by(username: 'root')

   purchase = GitlabSubscriptions::AddOnPurchase.create!(
     subscription_add_on_id: addon.id,
     namespace: group,
     quantity: 10,
     started_at: 1.day.ago,
     expires_on: 1.year.from_now,
     purchase_xid: "dev-test",
     organization_id: 1
   )

   GitlabSubscriptions::UserAddOnAssignment.create!(
     add_on_purchase: purchase,
     user: user
   )
   ```

4. **`duo_remote_flows_enabled`** on the project's namespace settings (already enabled for `gitlab-duo` group)

5. **CI identity verification disabled** (blocks workload creation otherwise):
   ```ruby
   ApplicationSetting.current.update!(ci_requires_identity_verification_on_free_plan: false)
   ```

6. **Project must have at least one commit** (for the source ref):
   ```bash
   curl -s --request POST \
     --url "http://gdk.test:8080/api/v4/projects/20/repository/files/README.md" \
     --header "PRIVATE-TOKEN: $PAT" \
     --header "content-type: application/json" \
     --data '{"branch":"main","content":"# Test","commit_message":"Initial commit"}'
   ```

7. **`gitlab-http-router` service must be running** (needed for git operations during workload creation):
   ```bash
   fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk start gitlab-http-router'
   ```

## Creating a PAT via Rails Console

```ruby
user = User.find_by(username: 'root')
token = user.personal_access_tokens.create!(
  name: "dev-test-#{Time.now.to_i}",
  scopes: [:api],
  expires_at: 1.day.from_now
)
token.set_token("glpat-my-custom-token")
token.save!
```

## Creating a Workflow

```bash
curl -s --request POST \
  --url "http://gdk.test:8080/api/v4/ai/duo_workflows/workflows" \
  --header "PRIVATE-TOKEN: $PAT" \
  --header "content-type: application/json" \
  --data '{
    "project_id": 20,
    "agent_privileges": [1,2,3,4,5],
    "workflow_definition": "developer/experimental",
    "allow_agent_to_request_user": false,
    "goal": "Create a hello world file",
    "environment": "web",
    "start_workflow": true
  }'
```

The `start_workflow: true` flag makes Rails also create a CI workload (job) that will run the CLI.

**Gotcha**: When running the CLI locally, use `start_workflow: false`. Using `start_workflow: true` triggers a CI job that tries to acquire the runner lock. If the runner is already busy or you then run the CLI locally too, you get **error 1013** (runner lock conflict). Set `start_workflow: false` to create the workflow without spawning a CI job, then run the CLI manually.

**Gotcha**: The `developer/experimental` flow uses an `issue_parser` entry point. The `goal` must be a **GitLab issue URL** (e.g. `http://gdk.test:8080/gitlab-duo/test/-/issues/1`), not a plain text string — otherwise the flow fails to parse the goal.

## Running CLI Locally Against a Workflow

Instead of waiting for the CI job, you can run the CLI directly:

```bash
cd /path/to/gitlab-lsp/packages/cli
node dist/index.js run \
  --existing-session-id <workflow_id> \
  --connection-type websocket \
  --gitlab-base-url http://gdk.test:8080 \
  --gitlab-auth-token $PAT \
  --insecure true
```

## CI Runner Setup

GDK ships with 30 instance runners in the DB, but **none have actual runner processes** — `contacted_at` is null for all of them. You must set up a real runner to execute workflow CI jobs.

The CI job has tag `gitlab--duo`, requires Docker image `registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.6`, and has a 2-hour timeout.

### Prerequisites

1. **Colima** must be running (`colima start`)
2. Docker context must be set to colima (`docker context use colima`)

### Create and register a runner

```bash
# 1. Create runner via API
curl -s --request POST \
  --url "http://gdk.test:8080/api/v4/user/runners" \
  --header "PRIVATE-TOKEN: $PAT" \
  --header "content-type: application/json" \
  --data '{"runner_type":"instance_type","tag_list":["gitlab--duo"],"run_untagged":false,"description":"Workflow runner"}'
# Note the token from response (glrt-...)

# 2. Register with Docker executor (run from GDK root)
docker run --rm --add-host gdk.test:172.16.123.1 \
  -v /Users/tomas/workspace/gl/gdk/tmp/gitlab-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner register \
  --non-interactive \
  --url "http://gdk.test:3000" \
  --token "<RUNNER_TOKEN>" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-extra-hosts "gdk.test:172.16.123.1" \
  --config /etc/gitlab-runner/gitlab-runner-config.toml

# 3. Start runner container
docker run -d --name gitlab-runner-hitl \
  --add-host gdk.test:172.16.123.1 \
  -v /Users/tomas/workspace/gl/gdk/tmp/gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner run \
  --config /etc/gitlab-runner/gitlab-runner-config.toml
```

**Volume mount gotcha**: Use a path under `/Users/tomas/` (Colima mounts home dir). Paths like `/tmp/` won't persist across the host/VM boundary.

### Managing the runner

```bash
docker logs gitlab-runner-hitl          # Check runner logs
docker stop gitlab-runner-hitl          # Stop
docker start gitlab-runner-hitl         # Start again
docker rm -f gitlab-runner-hitl         # Remove
```

### Current runner state

- Runner id: 31, token: stored in `~/.secrets/gdk` as `$GDK_RUNNER_TOKEN` (already in env)
- Config: `/Users/tomas/workspace/gl/gdk/tmp/gitlab-runner-config/gitlab-runner-config.toml`
- Container name: `gitlab-runner-hitl`

## WebSocket Origin Gotcha

Workhorse's duo workflow WebSocket handler uses gorilla/websocket `Upgrader` with default `CheckOrigin`, which rejects requests where the Origin header doesn't match the Host. The CLI inside Docker sends a mismatched Origin, causing **403 on WebSocket upgrade**.

**Symptom**: Workhorse log shows `"error":"failed to upgrade: websocket: request origin not allowed by Upgrader.CheckOrigin"`.

**Fix** (applied to local Workhorse source):

In `/Users/tomas/workspace/gl/gdk/gitlab/workhorse/internal/ai_assist/duoworkflow/handler.go`, change:
```go
upgrader: websocket.Upgrader{},
```
to:
```go
upgrader: websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool { return true },
},
```

Then rebuild and restart:
```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk/gitlab/workhorse && make'
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk restart gitlab-workhorse'
```

**This change is currently applied.** It will be reverted by `gdk update`. Re-apply after updates.

## Vite Requirement

DWS flow definitions make GraphQL queries to Rails that can trigger Vite asset lookups. If `vite` service is down, the flow fails with `Vite Ruby can't find styles/emoji_sprites.css`. **Start vite before running workflows:**

```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk start vite'
```

## CI Workload Flow (How Rails Spawns CLI)

The `StartWorkflowService` (`ee/app/services/ai/duo_workflows/start_workflow_service.rb`):
1. Creates a workload branch from the project's default branch
2. Builds a CI workload definition with environment variables and commands
3. Commands: install `@gitlab/duo-cli` via npm, then run `duo run --existing-session-id <id> --connection-type websocket`
4. The `DUO_CLI_VERSION` constant controls which npm version is installed
5. Job uses Docker image `workflow-generic-image:v0.0.6` and tag `gitlab--duo`

The CI job gets an OAuth token with scopes `ai_workflows mcp` (not full `api` scope). This token works for GraphQL and the `/ws` endpoint but **not** for REST endpoints like `/api/v4/version` (returns 403 insufficient_scope). This is expected — the CLI logs a warning but continues.

To test with a local CLI build instead of npm-installed, you'd need to modify `set_up_executor_commands` in `StartWorkflowService` — but it's easier to just run the CLI locally (see "Running CLI Locally" above).

## Services Required for Workflow E2E

All of these must be running:

```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk start \
  postgresql redis rails-web rails-background-jobs \
  gitlab-workhorse nginx praefect praefect-gitaly-0 \
  sshd gitlab-ai-gateway duo-workflow-service \
  gitlab-http-router vite'
```

Plus the Docker runner container (`docker start gitlab-runner-hitl`).

## Checking Workflow / Job Status

```bash
# Workflow status
curl -s --header "PRIVATE-TOKEN: $PAT" \
  "http://gdk.test:8080/api/v4/ai/duo_workflows/workflows/<id>" | python3 -m json.tool

# CI job trace (log output)
curl -s --header "PRIVATE-TOKEN: $PAT" \
  "http://gdk.test:8080/api/v4/projects/20/jobs/<job_id>/trace"

# Find job ID via Rails console
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk rails console' <<'RUBY' 2>&1 | grep 'RESULT:'
Ci::Build.where(project_id: 20).order(id: :desc).limit(5).each do |b|
  puts "RESULT:build #{b.id}: status=#{b.status} name=#{b.name} pipeline_source=#{b.pipeline.source}"
end
RUBY
```

## HITL (Human-In-The-Loop) Testing

The `developer/experimental` flow definition on DWS branch `ss/spike-hitl` includes a `human_input` node. When the agent reaches plan creation, the workflow transitions to `INPUT_REQUIRED` status and the WebSocket stream ends cleanly.

Key observations:
- The DWS sends `workflowStatus: "INPUT_REQUIRED"` in the final checkpoint event before closing the stream
- The CLI detects this via a `StreamEnd` event that carries the `workflowStatus` — `INPUT_REQUIRED` maps to `AgentStatus.InputRequired` → **exit code 75**
- Resume with `--existing-session-id <id> --approval true/false [--rejection-reason "..."]` — no `--goal` needed
- On the spike branch DWS re-pauses after every interaction (both approve and reject), so all resume runs also exit 75
- The `developer/experimental` flow requires goal to be an issue URL (see "Creating a Workflow" gotchas above)

## Policy Chain for `create_duo_workflow_for_ci`

```
ProjectPolicy:
  duo_agent_platform_enabled (Ai::DuoWorkflow.duo_agent_platform_available?)
    → self-managed: Ai::Setting.instance.duo_agent_platform_enabled
    → SaaS: root_namespace.duo_agent_platform_enabled
  & duo_workflow_available (StageCheck + allowed_to_use?)
    → StageCheck: License.feature_available?(:ai_workflows)
    → allowed_to_use?: checks add-on purchases (duo_enterprise seat)
  & developer_access
  → enables :create_duo_workflow_for_ci

WorkflowPolicy:
  duo_workflow_in_ci_available (project.duo_remote_flows_enabled)
  & can_update_workflow (owner check)
  → enables :execute_duo_workflow_in_ci
```
