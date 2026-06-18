# pi & qmd — global npm tools (via mise)

`pi` and `qmd` are npm packages managed by mise's `npm:` backend in
`~/.config/mise/config.toml`. Fish wrapper functions in
`fish/.config/fish/functions/{pi,qmd}.fish` pin `node@24` at runtime so the tools
work regardless of a project's local node version.

The pi config is stow-managed: `pi/.pi/agent/` → `~/.pi/agent/`.

- **Update:** `mise upgrade`
- **Runtime node pinning:** the fish functions call
  `mise exec node@24 -- command {pi,qmd}`; `npmCommand` in
  `pi/.pi/agent/settings.json` also uses `node@24`.
- If the global node major changes (e.g. 24 → 26), update the `node@24`
  references in the two fish functions and `pi/.pi/agent/settings.json`.
- Do **not** `npm i -g` these — it bypasses mise and installs a duplicate.

## qmd: better-sqlite3 native binding

`qmd` needs a `better-sqlite3` binding matching the Node ABI. If it errors with
`Could not locate the bindings file ... node-vXXX-darwin-arm64`, rebuild against
the pinned Node:

```sh
cd /Users/tomas/.local/share/mise/installs/npm-tobilu-qmd/*/lib/node_modules/@tobilu/qmd
mise exec node@24 -- npm rebuild better-sqlite3
```

Re-run after each `mise upgrade` that bumps qmd, if the error returns.
