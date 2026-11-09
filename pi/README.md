# pi & qmd — global npm tools (via mise)

`pi` and `qmd` are npm packages managed by mise's `npm:` backend in
`~/.config/mise/config.toml` (stow-managed: `mise/.config/mise/config.toml`). Fish wrapper functions in
`fish/.config/fish/functions/{pi,qmd}.fish` pin `node@24` at runtime so the tools
work regardless of a project's local node version.

The pi config is stow-managed: `pi/.pi/agent/` → `~/.pi/agent/`.

Extensions in `pi/.pi/agent/extensions/` are type-checked, not compiled (pi loads
them through jiti). `package.json` + `tsconfig.json` there exist only so nvim's
`ts_ls` and `npx tsc --noEmit` resolve node and `@earendil-works/*` types; the
types come from the mise pi install via its version-independent `latest` symlink.

- **Update:** `mise upgrade`
- **Runtime node pinning:** the fish functions call
  `mise exec node@24 -- command {pi,qmd}`; `npmCommand` in
  `pi/.pi/agent/settings.json` also uses `node@24`.
- If the global node major changes (e.g. 24 → 26), update the `node@24`
  references in the two fish functions and `pi/.pi/agent/settings.json`.
- Do **not** `npm i -g` these — it bypasses mise and installs a duplicate.

### pi-guard: fail sessions on the wrong pi

`extensions/pi-guard.ts` kills any session whose pi is not the mise-managed
install: `process.argv[1]` must run through
`mise/installs/npm-earendil-works-pi-coding-agent/`. A pi from anywhere else
(a stale `npm i -g` duplicate under a mise node version is the classic — its
bin dir shadows the backend on PATH inside node-pinned projects) lacks the
extension API the other extensions target: old pis fire `agent_start` but
never `agent_settled`, so task registries stick at "working", and APIs like
`pi.getSettings` are missing entirely (2026-11-09: pi 0.76.0 under
node/22.22.1 broke bash-timeout and every bash call in gitlab-lsp worktrees).

- Interactive: a blocking dialog explains the mismatch, then the session
  exits. Headless (`pi -p`/json/rpc): stderr message + `process.exit(1)` —
  `ctx.shutdown()` is not bound outside the TUI.
- `PI_GUARD_BACKEND` overrides the backend name (path-segment match);
  `PI_GUARD_ANY=1` skips the check (e.g. pi from a checkout on purpose).
- Tests: `node --test pi/tests/pi-guard.test.ts` (kept outside
  `extensions/` because pi auto-discovers every `*.ts` there and fails on
  files without a factory export). Type-check as usual with
  `npx tsc --noEmit` in `extensions/`.

## qmd: better-sqlite3 native binding

`qmd` needs a `better-sqlite3` binding matching the Node ABI. If it errors with
`Could not locate the bindings file ... node-vXXX-darwin-arm64`, rebuild against
the pinned Node:

```sh
cd /Users/tomas/.local/share/mise/installs/npm-tobilu-qmd/*/lib/node_modules/@tobilu/qmd
mise exec node@24 -- npm rebuild better-sqlite3
```

Re-run after each `mise upgrade` that bumps qmd, if the error returns.
