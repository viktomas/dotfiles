---
name: web-browser
description: "Drive a real Chrome browser - open pages, click, fill forms, read the accessibility tree, take screenshots, capture console/network logs. Can hand the window to the user to log in to a service, then continue with the saved session. Use for JS-heavy or authenticated pages, UI testing, and anything curl/web-search can't read. Keywords - browser, chrome, rodney, click, screenshot, login, headless, CDP. Never for gitlab.com (use gitlab-api) unless explicitly asked."
license: Apache-2.0, see LICENSE.md
---

# Web Browser

`rodney` (CLI over Chrome DevTools Protocol) drives a dedicated Chrome that
`scripts/browser` launches. Paths below are relative to this skill directory.

Don't use it when something lighter works: plain lookups → web-search skill,
static pages/APIs → `curl`, gitlab.com → gitlab-api skill.

## Lifecycle

```bash
scripts/browser start          # headless (default); no-op if already running
scripts/browser start --show   # visible window — use when a login is likely
scripts/browser show           # switch running browser to visible (reopens current URL)
scripts/browser hide           # back to headless
scripts/browser status
scripts/browser stop           # when done
```

- Profile lives in `~/.cache/agent-browser/profile` and **persists** across
  stop/start and headless/visible switches, so logins stick. It is separate from
  my everyday Chrome — never touch my real profile or kill my Chrome.
- One shared browser on `:9222`. If `status` shows it's already running,
  someone (maybe me) may be using it; reuse it, don't restart it blindly.
- Always use `scripts/browser`, never `rodney start` (broken `--show` in 0.4.0,
  and headful crashes on macOS).

## rodney commands

```bash
rodney open https://example.com     # then: rodney waitload / waitstable / waitidle
rodney url | rodney title
rodney ax-tree --depth 4            # best way to "see" page structure; cheap
rodney ax-find --role button --name "Save"
rodney text 'main h1'               # text of one element
rodney html 'form#login'            # HTML of element (or whole page, no arg — big!)
rodney js 'document.querySelectorAll("a").length'
rodney click 'button[type=submit]'
rodney input '#email' 'me@example.com'
rodney select '#country' 'CZ'
rodney wait '.results'              # wait for selector (ROD_TIMEOUT, default 30s)
rodney exists '.error'              # exit 0 yes / 1 no — usable in `if`
rodney screenshot /tmp/shot.png     # then `read` the png to look at it
rodney screenshot-el '.chart' /tmp/chart.png
rodney pages | rodney page 1 | rodney newpage URL | rodney closepage
rodney back | rodney forward | rodney reload
rodney download 'a.export' /tmp/export.csv
rodney pdf /tmp/page.pdf
```

Tips:
- Selectors are CSS. Find them via `ax-tree`/`html <sel>` first; don't guess.
- `js` wraps the arg as `() => { return (EXPR); }` — for multiple statements
  use an IIFE: `rodney js '(() => { const a = 1; return a + 1 })()'`. Use
  single quotes outside, double inside.
- Prefer `ax-tree`/`text` over screenshots for reading; screenshots for layout
  or visual verification.
- Exit codes: 0 ok, 1 check failed, 2 error (no browser, timeout, bad args).

## Logging in (ask the user)

It is fine — and expected — to ask me to log in when a page needs auth. Never
ask for passwords/tokens in chat and never type credentials yourself.

1. Detect it: redirected to a login/SSO URL, `rodney exists 'input[type=password]'`,
   or a 401/403 page. First check — the saved profile may already be logged in.
2. `scripts/browser show` (window appears at the current URL).
3. Ask me concisely, e.g. *"Please log in to <service> in the Chrome window I
   just opened (the agent profile, not your main Chrome). I'll wait up to 5 min."*
4. Wait with a **positive** signal of being logged in (element only present when
   authenticated, or URL back on the app), not "login form gone":
   ```bash
   scripts/browser wait-for 'location.hostname === "app.example.com" && !!document.querySelector("[data-user-menu]")' 300
   ```
   Run it with a bash timeout > the wait. On timeout, ask me what's up instead
   of looping forever.
5. Continue (optionally `scripts/browser hide`). The session is saved in the
   profile, so next time it should just work.

Also hand the window over (same flow) for CAPTCHAs, 2FA prompts, and before
any irreversible action — submitting payments, deleting, publishing, sending
messages — unless I explicitly asked for exactly that action.

Screenshots/HTML of authenticated pages contain my real data: keep them in
`/tmp`, don't paste them anywhere external.

## Extra helpers (CDP scripts, same browser)

```bash
node scripts/dismiss-cookies.js           # accept EU cookie banners
node scripts/dismiss-cookies.js --reject  # reject where possible
node scripts/pick.js "Click the submit button"
    # needs visible window: I click element(s) (Cmd+click multi, Enter done);
    # prints selectors/HTML. Use when I say "this thing here".
node scripts/logs-tail.js [--follow]      # console, JS errors, network (JSONL)
node scripts/net-summary.js               # summary of network responses
```

The logger starts automatically with `scripts/browser start` and writes to
`~/.cache/agent-web/logs/YYYY-MM-DD/<targetId>.jsonl`. Use it to debug web
apps (console errors, failed requests) — rodney has no log capture itself.

## Env overrides

`BROWSER_PORT` (9222), `BROWSER_HOME` (`~/.cache/agent-browser`), `CHROME_BIN`,
`ROD_TIMEOUT` (rodney waits, 30s). For an isolated second browser export all of
`BROWSER_PORT`, `BROWSER_HOME` and `RODNEY_HOME` (rodney's state is global).
