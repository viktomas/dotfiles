---
name: fj
description: Forgejo CLI (fj) against my self-hosted Forgejo on n - issues, PRs, repos, Actions runs. Use for anything on http://n:3000 (tomas/notes, finance, agent, home-server, dotfiles, ...), i.e. the repos that are NOT on gitlab.com. Keywords - forgejo, fj, n:3000, ssh://fg, @ai agent, pi-agent.
---

# fj — my Forgejo

`brew install forgejo-cli`. My instance is **`http://n:3000`** (plain HTTP,
tailnet/LAN only). `$FORGEJO_TOKEN` is in the environment and is an **admin
token for `tomas`** — everything you do with it is attributed to me, so treat
merging, closing and deleting as things to ask about first.

One-time (already done on this machine; the keys land in
`~/Library/Application Support/forgejo-cli.forgejo-cli/keys.json`):

```sh
fj -H http://n:3000 auth add-token "$FORGEJO_TOKEN"
fj -H http://n:3000 whoami        # -> tomas@n:3000
```

## The two shapes of command

There is **no `list`** — it is `search`. And only the repo-wide verbs take
`-r`; the ones that act on a number infer the repo from the checkout you are
standing in.

| takes `-r <owner/repo>` | infers the repo from the git remote |
|---|---|
| `issue search`, `issue create` | `issue view/edit/comment/close` |
| `pr search`, `pr create` | `pr view/merge/comment/status/checkout` |
| `actions tasks`, `release list` | `repo view <owner/repo>` (positional) |

```sh
H="-H http://n:3000"
fj $H issue search -r tomas/agent -s open        # -s open|closed|all
fj $H pr search    -r tomas/finance -s all
fj $H actions tasks -r tomas/agent               # CI runs, newest first
fj $H repo view tomas/notes
fj $H issue create -r tomas/agent "title" --body "..."
fj $H pr create -r tomas/finance "feat(x): title" --base master --head my-branch --body '...'
```

The title is **positional** — there is no `--title` — and `-R <remote>` is only
for the number-targeted verbs, never for `create`.

## The ssh-remote gotcha

My checkouts push over the ssh alias `fg` (`ssh://fg/tomas/<repo>.git`), and
several also have a `gitlab` remote. fj resolves `fg` to `https://n`, which is
not the instance, and with two remotes it may pick the GitLab one — so inside
`~/private/notes`, `~/workspace/private/finance` or `home-server` a bare
`fj issue view 3` fails with a 403 or a connection error.

- Repo-wide verbs: always pass `-H http://n:3000 -r tomas/<repo>` and it does
  not matter where you are.
- Number-targeted verbs: add the HTTP remote to that checkout once and name it,
  `git remote add fgh http://n:3000/tomas/<repo>.git` then
  `fj issue view 3 -R fgh`. Pushing still goes over `fg`.
- `~/workspace/private/agent` already has an HTTP `origin`, so everything works
  there with no flags.

## Output

`fj` wraps every value in Unicode isolate characters (U+2068/U+2069), even
piped and with `--style minimal`. Strip them before parsing:

```sh
fj $H issue search -r tomas/agent -s open | sed 's/[⁨⁩]//g'
```

When `fj` has no verb for what you need (branch protections, secrets, labels,
raw file contents), the API always works:

```sh
curl -sS -H "Authorization: token $FORGEJO_TOKEN" http://n:3000/api/v1/repos/tomas/agent/issues
```

## What lives there

`tomas/notes` (`master`), `tomas/finance` (`master`), `tomas/agent` (`main`),
`tomas/home-server` (`main`), `tomas/dotfiles` (`master`), plus smaller ones.
The first three are served by the **`@ai` agent**: commenting `@ai <request>`
on an issue there runs pi in a Forgejo Actions job and answers in the thread
(`tomas/agent` is the project, and its `docs/` explain the whole thing).
`fj $H actions tasks -r tomas/<repo>` is how you see those runs from here.
