---
name: gdk
description: GitLab Development Kit (GDK) — local GitLab development environment. Use when the user mentions GDK, starting/stopping GitLab locally, running rails console, GDK services, or local GitLab development.
metadata:
  autoload-keywords: gdk, gdk start, gdk stop, gdk update, gdk status, gdk reconfigure, local gitlab
---

# GitLab Development Kit (GDK)

GDK is the local development environment for GitLab. It lives at `/Users/tomas/workspace/gl/gdk`.

## Network Setup

GDK uses a custom loopback alias for its hostname:

- **Hostname**: `gdk.test`
- **Listen address**: `172.16.123.1`
- **Web URL**: `http://gdk.test:8080` (NGINX-proxied)
- **SSH**: `gdk.test:2222`

A LaunchDaemon at `/Library/LaunchDaemons/org.gitlab1.ifconfig.plist` creates the loopback alias on boot. If services like `gitlab-workhorse` or `sshd` fail with `bind: can't assign requested address`, the alias is missing.

**Diagnosis**: `ifconfig lo0 | grep 172.16` — if no output, the alias is missing.

**Fix** (requires `sudo` — ask the user to run these):

```bash
sudo ifconfig lo0 alias 172.16.123.1
# If daemon got unloaded:
sudo launchctl load /Library/LaunchDaemons/org.gitlab1.ifconfig.plist
```

After alias is restored (agent can do this): `gdk restart gitlab-workhorse sshd`

## Admin Credentials

- **Username**: `root`
- **Password**: `5iveL!fe`

## Configuration

Config file: `/Users/tomas/workspace/gl/gdk/gdk.yml`

Current config highlights:
- AI gateway enabled (`http://gdk.test:5052`)
- Duo workflow enabled
- NGINX enabled (GDK accessible at `:8080`)
- License provisioning enabled (Ultimate + Duo Enterprise)
- Vite enabled (webpack disabled)
- Topology service disabled
- mise enabled (asdf opted out)

To view all config: `gdk config list`
To set a value: `gdk config set <key> <value>`
After config changes: `gdk reconfigure`

## Shell Requirement

The `gdk` command requires mise-managed Ruby. In non-interactive bash, `mise` isn't activated, so `gdk` fails with "You are using Ruby 2.6.10". **Always run gdk commands through fish:**

```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk status'
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk start postgresql redis rails-web'
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk rails console'
```

## Rails Console

Use heredoc to pipe Ruby commands. Output is noisy — filter with `grep 'RESULT:'`:

```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk rails console' <<'RUBY' 2>&1 | grep 'RESULT:'
puts "RESULT:answer: #{User.count}"
RUBY
```

**Gotcha**: If PostgreSQL shows `too many clients already`, restart postgresql + rails:
```bash
fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk restart postgresql rails-web rails-background-jobs'
```

## Common Commands

```bash
gdk start                    # Start all services
gdk stop                     # Stop all services
gdk restart                  # Restart all services
gdk status                   # Check service status
gdk update                   # Pull latest code + update dependencies + migrate DB
gdk reconfigure              # Regenerate config files after gdk.yml changes
gdk tail                     # Tail all service logs
gdk tail <service>           # Tail specific service logs
gdk doctor                   # Run diagnostics
gdk pristine                 # Reset caches/deps without deleting data
gdk kill                     # Forcibly kill all services (use when stop hangs)
gdk rails <command>          # Run Rails commands (e.g., gdk rails console)
gdk psql                     # PostgreSQL console (gitlabhq_development)
gdk open                     # Open GitLab in browser
gdk predictive               # Run tests/linters/coverage for local changes
gdk predictive --rspec       # Only RSpec tests
gdk predictive --jest        # Only Jest tests
gdk predictive --rubocop     # Only RuboCop on changed Ruby files
gdk predictive --yes         # Skip confirmation prompt
gdk switch <branch>          # Switch gitlab to branch + update services
gdk sandbox                  # Ephemeral database sandbox
gdk feature-flags            # List feature flags
gdk feature-flags reset      # Reset all to defaults
```

## Services

GDK manages these services (via runsv):

| Service               | Purpose                    |
|----------------------|----------------------------|
| postgresql           | Database                   |
| redis                | Cache / queues             |
| praefect             | Gitaly cluster manager     |
| praefect-gitaly-0    | Git storage                |
| rails-web            | GitLab Rails (Puma)        |
| rails-background-jobs| Sidekiq workers            |
| gitlab-workhorse     | Git HTTP / reverse proxy   |
| gitlab-http-router   | HTTP routing               |
| sshd                 | Git SSH access             |
| vite                 | Frontend dev server        |
| nginx                | Reverse proxy (port 8080)  |
| gitlab-ai-gateway    | AI features gateway        |
| duo-workflow-service | Duo workflow               |

Start/stop/restart individual services: `gdk start <service>` / `gdk stop <service>`

## Logs

Service logs are in `/Users/tomas/workspace/gl/gdk/log/<service>/current`.

```bash
# Check why a service is failing
cat log/gitlab-workhorse/current | tail -20
cat log/rails-web/current | tail -20
```

## CI Runners

GDK ships with 30 phantom instance runners in the DB (never contacted). To run CI jobs locally, you need a real Docker runner. See [resources/duo-workflows.md](resources/duo-workflows.md) for full setup.

Quick check: `docker ps | grep gitlab-runner` — if no output, the runner container isn't running.

```bash
colima start                              # Start Docker VM (if not running)
docker start gitlab-runner-hitl           # Start existing runner container
docker logs -f gitlab-runner-hitl         # Watch runner pick up jobs
```

## Troubleshooting

1. **Services won't bind** → Missing loopback alias (see Network Setup above)
2. **Rails won't start** → Check `log/rails-web/current` for migration errors; run `gdk update` or `cd gitlab && bundle exec rails db:migrate`
3. **Stale state** → `gdk pristine` resets caches without deleting data
4. **Everything stuck** → `gdk kill` then `gdk start`
5. **Config changes not taking effect** → `gdk reconfigure` after editing `gdk.yml`
6. **WebSocket 403 on duo workflows** → Workhorse origin check. See [resources/duo-workflows.md](resources/duo-workflows.md) "WebSocket Origin Gotcha"
7. **Vite asset errors in DWS flows** → Start vite: `fish -c 'cd /Users/tomas/workspace/gl/gdk && gdk start vite'`

## GitLab Source

The GitLab Rails app is at `/Users/tomas/workspace/gl/gdk/gitlab/`. This is a regular git checkout that GDK manages.

## Feature Flags

Via Rails console:
```bash
gdk rails console
# Then: Feature.enable(:flag_name) / Feature.disable(:flag_name)
```

## Application Settings

Common settings that block features in development. Check/change via Rails console:

```ruby
# CI identity verification (blocks CI job creation)
Gitlab::CurrentSettings.ci_requires_identity_verification_on_free_plan
ApplicationSetting.current.update!(ci_requires_identity_verification_on_free_plan: false)

# Duo features
Gitlab::CurrentSettings.duo_features_enabled

# Duo Agent Platform (instance-level, needed for non-SaaS)
Ai::Setting.instance.duo_agent_platform_enabled
Ai::Setting.instance.update!(duo_agent_platform_enabled: true)
```

## License / Subscription

See [resources/license-debugging.md](resources/license-debugging.md) for debugging license activation issues, customers portal URL configuration, and activation troubleshooting.

## AI Gateway / Duo Setup

See `doc/howto/ai/_index.md` for the full Duo setup guide (AI gateway, Duo Workflow, Runner, Knowledge Graph). See `doc/howto/ai/gitlab_ai_gateway.md` for AI gateway-specific config. API keys and auth config live in `gitlab-ai-gateway/.env`.

See [resources/duo-workflows.md](resources/duo-workflows.md) for Duo Workflow testing setup (CI workflows, DWS branches, permissions, add-on provisioning).

### Duo Group

A `gitlab-duo` group (id: 96) exists with `experiment_features_enabled` and `duo_features_enabled` on. It contains a `gitlab-duo/test` project (id: 20) for testing Duo features. URLs:
- Group: `http://gdk.test:8080/gitlab-duo`
- Project: `http://gdk.test:8080/gitlab-duo/test`

## GDK Documentation

Full docs are at `/Users/tomas/workspace/gl/gdk/doc/`. Key pages:
- `doc/howto/local_network.md` — loopback alias setup and persistence
- `doc/configuration.md` — all gdk.yml options
- `doc/gdk_commands.md` — full command reference
- `doc/howto/ai/_index.md` — AI/Duo setup (gateway, workflow, runner)
- `doc/howto/ai/gitlab_ai_gateway.md` — AI gateway config
- `doc/troubleshooting/` — common issues
