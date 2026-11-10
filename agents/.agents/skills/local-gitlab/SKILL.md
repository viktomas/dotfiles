---
name: local-gitlab
description: Use the local GitLab instances — Caproni (k3d Kubernetes clusters running the GitLab Helm chart) that replaced GDK. Use when testing against a local GitLab, running rails/rake/feature flags on it, minting tokens, enabling Duo/AI Gateway, or when a task mentions GDK, gdk.test, caproni, sandbox GitLab or the agent-a/agent-b instances.
---

# Local GitLab = Caproni (GDK is gone)

GDK (`~/workspace/gl/gdk`, `gdk.test:3000`) was **deleted on 2026-11-10**. Anything that
still says `gdk`, `gdk.test`, `GDK_TOKEN` or `172.16.123.1` is stale. Its unpushed
branches and stashes are bundled in `~/workspace/gl/work/backups/gdk-2026-11-10/`
(the README there explains how to restore them).

[Caproni](https://gitlab-org.gitlab.io/caproni/) runs GitLab as a real Kubernetes cluster:
the GitLab Helm chart plus `gitlab-dev-stack` (CNPG Postgres, Valkey, NATS, Garage S3,
ClickHouse), Gitaly and a gitlab-runner. It's configured by
[gitlab-org/gitlab-caproni](https://gitlab.com/gitlab-org/gitlab-caproni) (YAML, Helm values,
fragments). The `caproni` CLI and k3d/helm/kubectl come from that repo's mise config.

## The instances

Both are k3d clusters on **one shared Colima VM** (profile `default`, docker runtime,
8 CPU / 40 GiB / 100 GiB disk). Each one is a git worktree of `gitlab-caproni`.

| | A | B |
|---|---|---|
| Dir (run `caproni` here) | `~/workspace/gl/caproni-agent-a` (branch `agent-a`) | `~/workspace/gl/caproni-agent-b` (branch `agent-b`) |
| URL | `http://gitlab.a.caproni.test` | `http://gitlab.b.caproni.test:8080` |
| Host ports | 80 / 443 / ssh 12222 | 8080 / 8443 / ssh 12223 |
| HTTPS URL | `https://gitlab.a.caproni.test` | `https://gitlab.b.caproni.test:8443` |
| k3d cluster | `caproni-agent-a-e8c041` | `caproni-agent-b-5b86a2` |
| kube context | **`caproni-a`** (ns `gitlab`) | **`caproni-b`** (ns `gitlab`) |
| Env vars | `$CAPRONI_A_URL`, `$CAPRONI_A_TOKEN` | `$CAPRONI_B_URL`, `$CAPRONI_B_TOKEN` |

- Main clone: `~/workspace/gl/gitlab-caproni` (on `main`, isn't running anything).
- Per-instance config: `caproni.local.yaml` in each dir (gitignored). It sets `BASE_DOMAIN`,
  `driver: k3d`, `cluster.name.strategy: directory-hash` and the port mappings.
- `~/.secrets/caproni` holds the URLs and root PATs (scopes `api, read_user, read_repository,
  write_repository, ai_features`, they expire around 2027-09). fish sources it, so the vars
  are in your env. In bash, run `source ~/.secrets/caproni`.
- Hostnames are on the `127.0.0.1 localhost …` line of `/etc/hosts`. Tomas added them by
  hand, so `caproni update-etc-hosts --remove` won't remove them.
- **B caveat:** the chart has no external-port setting, so B's web UI builds links and
  redirects for `:80`, which is instance A. The API, git over HTTP, glab and the runner work.
  Use A for browser flows.
- No fragments are enabled (no AI Gateway or Duo) and there's no edit mode: both run the
  stock chart images. `repos/` is empty in both.

## Source code (read here, not in Caproni)

- Monolith: `~/workspace/gl/gitlab/main` (bare repo + worktrees, use the `git-worktree` skill)
- AI Gateway / DWS: `~/workspace/gl/ai-assist/main`
- Caproni rig itself: `~/workspace/gl/gitlab-caproni` (`AGENTS.md`, `docs/`,
  `docs/migrating-from-gdk.md`). Upstream skills live in `gitlab-caproni/skills/`:
  `caproni` (paused pods, an interrupted `up`), `caproni-kubectl`, `caproni-stern`,
  `service-logs`. Read them for anything deeper than this page.

## kubectl / helm (from any directory)

`kubectl` and `helm` are global mise tools, and `~/.kube/config` has a context per instance.
**There's no current-context on purpose**, so you always have to name the instance with
`--context`. Both short contexts default to the `gitlab` namespace. Other namespaces are
`gitlab-dev-stack` (Postgres, Valkey, Garage, NATS, ClickHouse), `cert-manager` and
`cnpg-system`.

```bash
kubectl --context caproni-a get pods
kubectl --context caproni-b logs -l app=webservice -c webservice -f
kubectl --context caproni-a -n gitlab-dev-stack get pods
helm --kube-context caproni-a list -A
# k9s isn't installed globally: use `caproni k9s` from the instance dir
```

If a context is missing or stale (for example after `caproni destroy && caproni up`, which
recreates the cluster), run `caproni set-kube-context` in the instance dir. That rewrites
`caproni-agent-<x>-<hash>` in place, and `caproni-a`/`caproni-b` are aliases of the same
cluster/user entries, so they keep working. If they're gone, recreate them:
`kubectl config set-context caproni-a --cluster=caproni-agent-a-e8c041 --user=caproni-agent-a-e8c041 --namespace=gitlab`.

## caproni / mise tasks (from the instance dir)

Caproni picks the cluster by walking up from the cwd to `caproni.yaml` (or `-c <dir>/caproni.yaml`).
`caproni kubectl …` from the dir works too and is the same as `kubectl --context`.

```bash
cd ~/workspace/gl/caproni-agent-a
caproni status                          # cluster state (start here)
mise run gitlab:rootpassword            # root password (user: root)
mise run gitlab:psql                    # psql as superuser in the CNPG pod
```

Rails without edit mode runs in the **toolbox pod** (`-e production`, the code is the image's
release, not your checkout):

```bash
kubectl --context caproni-a exec deploy/gitlab-toolbox -c toolbox -- \
  gitlab-rails runner -e production 'Feature.enable(:my_flag)'
kubectl --context caproni-a exec -it deploy/gitlab-toolbox -c toolbox -- gitlab-rails console -e production
kubectl --context caproni-a exec deploy/gitlab-toolbox -c toolbox -- gitlab-rake <task>
```

Mint a PAT (let GitLab generate it, don't `set_token`):

```bash
kubectl --context caproni-a exec deploy/gitlab-toolbox -c toolbox -- gitlab-rails runner -e production '
t = User.find_by_username("root").personal_access_tokens.create!(scopes: ["api","read_user"], name: "local-#{Time.now.to_i}", expires_at: 90.days.from_now)
puts t.token'
```

OAuth password grant is disabled. Get tokens with the PAT recipe above, not with ROPC.

API, glab and the Duo CLI:

```bash
curl -s -H "PRIVATE-TOKEN: $CAPRONI_A_TOKEN" "$CAPRONI_A_URL/api/v4/user"
GITLAB_HOST=gitlab.a.caproni.test GITLAB_TOKEN=$CAPRONI_A_TOKEN glab api user
GITLAB_HOST=gitlab.b.caproni.test:8080 GITLAB_TOKEN=$CAPRONI_B_TOKEN glab api user
# both hosts have `api_protocol: http` in glab's config (GitLab's external_url is http)
GITLAB_TOKEN=$CAPRONI_A_TOKEN GITLAB_BASE_URL=$CAPRONI_A_URL duo …   # override any gitlab.com GITLAB_TOKEN
```

## TLS / certificates

GitLab's external URL is **http**, so use the `http://` URLs by default. Traefik also serves
https on 443/8443 with a cert from that cluster's own "Caproni Dev CA"
(`~/.local/share/caproni/<cluster>/pki/current/ca.crt`). The CA is regenerated when the cluster
is recreated. `caproni-trust` (in `~/bin`) trusts these CAs:

- It builds `~/.local/share/caproni/ca-bundle.pem` from every cluster's CA. fish exports it as
  `NODE_EXTRA_CA_CERTS`, and git uses it through `http.https://gitlab.<x>.caproni.test[:port]/.sslCAInfo`.
  None of this needs sudo, so `caproni-trust --no-keychain` is safe for agents to run.
- It adds each CA to the macOS System keychain (`caproni ca trust` per dir, which **needs sudo**,
  so Tomas runs plain `caproni-trust`). That covers `/usr/bin/curl`, glab and other Go tools,
  browsers and `node --use-system-ca`.

Rerun both parts after recreating a cluster or adding an instance. If you hit TLS errors before the keychain step:
`curl --cacert ~/.local/share/caproni/ca-bundle.pem https://…`, or just use http.

## Lifecycle

| Task | Command (from the instance dir) |
|---|---|
| Stop / start one instance | `caproni down` / `caproni up` |
| Stop / start the host VM (both instances) | `colima stop` / `colima start` (profile `default`) |
| Apply `caproni.local.yaml` changes | `caproni up` |
| Redeploy one release | `caproni deploy --repo <name>` |
| Update the rig and GitLab version | `git fetch && git rebase origin/main && mise install && caproni up` |
| Update `repos/` checkouts (edit mode only) | `caproni update` |
| Wipe and rebuild an instance | `caproni destroy && caproni up` (takes about 15 min) |
| Diagnose | `caproni doctor`, `caproni --debug <cmd>` (not `LOG_LEVEL=debug`, which breaks k3d) |

**`caproni up` is slow (8–15 min cold) and runs `helm --wait`.** Never run it as a blocking
tool call. An interrupted call leaves an orphaned helm process and a release stuck in
`pending-install`. Start it in the background and poll:

```bash
nohup caproni up > /tmp/caproni-up-a.log 2>&1 &
tail -5 /tmp/caproni-up-a.log
```

`cluster is ready` means the charts are installed. Migrations and the toolbox can need a few
more minutes. Check that `curl -s -o /dev/null -w '%{http_code}' $CAPRONI_A_URL/users/sign_in`
returns 200.

**Never run two `caproni up` at the same time** (one per instance included). They share the
VM disk and the managed registry cache, and the simultaneous pulls during setup evicted
instance A's pods with DiskPressure.

## Edit mode (run your branch's code)

The stock instances run released images. To test unmerged monolith code:

1. Put a checkout at `<instance>/repos/gitlab`, either a clone or a worktree of
   `~/workspace/gl/gitlab` on your branch. It must exist before `caproni up`.
2. In `caproni.local.yaml`: `repositories: { gitlab: { edit_reloaders: [gitlab, sidekiq] } }`.
   Always include sidekiq along with puma, or CI jobs stay in `created` forever.
3. `caproni up`, then `caproni run`. It's a long-lived foreground process, so run it in tmux
   (`tui-testing` skill) or a separate zellij tab. Puma and Vite run locally through mirrord
   with hot reload. A green favicon means edit mode is serving the requests.
4. Rails commands now go through the local checkout:
   `cd repos/gitlab && .gitlab/caproni/exec.sh bundle exec rails runner '…'`.
   Seeds: `RAILS_ENV=development .gitlab/caproni/exec.sh bundle exec rake db:seed_fu`.
5. Specs: `mise run gitlab:rspec spec/…` from the instance dir.

## Duo / AI Gateway

This isn't enabled on either instance. GDK used to have duo_workflow and AIGW with a Duo
Enterprise license. To enable it on an instance:

```yaml
# caproni.local.yaml (keep the existing variables/cluster keys)
extends:
  - fragments/caproni.ai-gateway.yaml
repositories:
  gitlab:
    edit_reloaders: [gitlab, sidekiq]
  ai-gateway:
    edit_reloaders: [ai-gateway]
```

Then `caproni up`, `export ANTHROPIC_API_KEY=…`, `op signin` (for the EE license via
1Password, `mise set -E local CAPRONI_ACTIVATE_LICENSE=1`) and `caproni run`. The first
`caproni run` creates the API-key secret, activates EE, starts local AIGW and DWS, and seeds the
feature flags, the AI catalog, a Duo Enterprise group and the `gitlab-duo/test` project.
AIGW needs edit mode. Details:
`gitlab-caproni/docs/fragments/gitlab.md#ai-gateway` and `docs/fragments/ai-gateway.md`.

The old Duo test clone `~/workspace/test/test` still points at
`http://gdk.test:3000/gitlab-duo/test.git` (dead). After seeding Duo on an instance, repoint
it: `git -C ~/workspace/test/test remote set-url origin http://gitlab.a.caproni.test/gitlab-duo/test.git`.

## Adding instance C

```bash
cd ~/workspace/gl/gitlab-caproni && git worktree add -b agent-c ../caproni-agent-c origin/main
cd ../caproni-agent-c && mise trust -y && mise install
# caproni.local.yaml: copy B's, with BASE_DOMAIN c.caproni.test and ports 8180:80, 8444:443, 12224:12222
nohup caproni up > /tmp/caproni-up-c.log 2>&1 &
# Tomas adds gitlab.c.caproni.test to /etc/hosts (sudo)
caproni set-kube-context && kubectl config set-context caproni-c --cluster=<caproni-agent-c-hash> --user=<same> --namespace=gitlab
caproni-trust          # Tomas (sudo); agents: caproni-trust --no-keychain
```

Consider giving the VM more memory first: `colima stop && colima start --cpu 8 --memory 48`.

## Troubleshooting

See [ai-owned-troubleshooting.md](./ai-owned-troubleshooting.md). Add an entry every time
you debug a problem with a local instance.
