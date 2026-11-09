# Global skills budget + description rewrites (proposal)

**Landed 2026-11-09** (owner decisions): the 8 rewrites + gitlab-api in
commits 230d021/426119a, smoke-verified 12/12; the git-guard trim in
94d98a2. Deferred by the gardener's own call (decision 7, delegated):
trimming the in-band keyword tails (fj, pdf, projects) below the
5,600-byte budget — no eval evidence they're removable, and the budget
is met. This file is retained as the decision record.

Global pass, 2026-11-09. Applies the agent-scaffolding Phase 2/3 budgets to
the global agent scope (`agents/.agents/skills/`, `pi/.pi/agent/skills/`,
`pi/.pi/agent/AGENTS.md`). Nothing here is merged without the owner; each
rewrite is one concern, gated on a cheap trigger smoke-run (see Eval plan).
Rev 2: corrected after the 2026-11-09 opus review (word counts measured with
`wc -w`, the same counter check.sh uses — a standalone em dash counts as a
word; three rewrites were over the limit and have been tightened).

## Measured baseline (live session, 2026-11-09, this repo)

| Section | Chars | ~Tokens | Curatable |
|---|---|---|---|
| global `pi/.pi/agent/AGENTS.md` | 2,482 | 620 | yes |
| skill descriptions (21 model-invocable, incl. repo-local nvim-theme) | 5,773 (5,836 bytes) | ~1,450 | yes |
| skills XML wrapper | 3,507 | 877 | no (harness) |

The description block is the largest curatable always-loaded item in every
pi session, in every repo (pi loads it; claude and duo load their own
files — `~/.claude/CLAUDE.md` and `~/.gitlab/duo/AGENTS.md`). Since the
2026-11-05 curation it has drifted: `orbit` and `review-depth` were added,
`mr-review` merged into `review` (finding 3 verified — re-check at every
gardener pass; the extended check.sh validator in
`global-hook-scope.md` makes that automatic).

## Budgets (owner picks the numbers)

- **Per-skill description:** 30–55 words (`wc -w`), trigger-style (the same
  band `.agents/check.sh` enforces repo-local). Exceptions allowed below
  30 for pure keyword triggers that verifiably fire (downloads,
  git-worktree, wait-for) — under-length costs nothing; over-length is
  paid every session.
- **Description block total:** ≤ 5,600 bytes across the model-invocable
  set (now 5,836; the rewrites below land at ~5,630 — the budget holds
  them there, it does not pretend the rewrites reach 5,000). Tightening
  further would mean trimming in-band keyword tails (fj, pdf, projects) —
  owner's call, not proposed now.
- **`pi/.pi/agent/AGENTS.md`:** 60 lines (now 57; the git-guard trim below
  takes it to 54). Placeholder — owner picks; enforced by the extended
  check.sh.

## Description rewrites

10 of 21 model-invocable descriptions are outside the 30–55 band (5 over:
task-tabs 85, review-depth 77, web-browser 70, epub 63, subagent 62; 5
under: downloads 26, git-worktree 26, wait-for 28, tui-testing 19,
web-search 15), and gdk is in-band (43) but not trigger-style. gitlab-api
was already rewritten (17 → 36 words) and merged with the claude duplicate
in this pass — see AUDIT.md. The 8 rewrites below cover the rest.
`gitlab-mr-comments` is a git submodule of the published skill; any
description change there goes upstream, not here. downloads, git-worktree
and wait-for stay as-is (effective keyword triggers, cheap).

### task-tabs (85 → 54)

> Inspect and drive the zellij tabs in task sessions — see what's open or running, read a pane's screen, open/close tabs, run commands in another task's session. Use when the user asks what's running in a task, wants to tidy or clean up tabs or sessions, or wants something started or typed into another session.

Keeps every trigger phrase the review flagged: "what's open", "what's
running", "clean up", "close tabs". Drops the trailing keyword list
(zellij/tabs/panes all already appear).

### review-depth (77 → 53)

> Deep opt-in checks for an MR review - validate the problem behind an MR or challenge the solution with alternative designs a blind subagent proposes from the requirements alone. Use when asked to validate the problem, challenge the solution, question whether an MR is needed, find alternative designs, or cut requirements to reduce complexity.

Drops the parenthetical capability detail; the body carries it.

### web-browser (70 → 55)

> Drive a Chrome browser — open pages, click, fill forms, take screenshots, capture console/network logs; can hand the window to the user to log in and continue with the saved session. Use for JS-heavy or authenticated pages, UI testing, and anything curl/web-search can't read. Never for gitlab.com (use gitlab-api) unless asked. Keywords - rodney, headless, CDP.

Keeps the gitlab.com exclusion; "accessibility tree" moves to the body
only; the keyword tail is kept short but preserves rodney/headless/CDP.

### epub (63 → 54)

> Turn a markdown report (or plain text file) into a validated EPUB 3 book for an e-ink reader — renders d2 diagrams, SVG, diffs and images to grayscale. Use whenever I ask for an epub, a book, something to read on the PocketBook/Kobo, or "make this a book". Keywords - epub, ebook, e-ink, pocketbook, kobo.

Drops "convert report to book", "mobi", "kindle", "epubcheck" from the
keyword tail.

### subagent (62 → 54)

> Spawn a one-shot subagent in a separate session to investigate or research without polluting the main context. Use when a question obviously doesn't need your current full context. Also runs GitLab Duo CLI headless, auto-checked by a pi Sonnet reviewer — use whenever I say duo subagent, run duo, send duo, delegate to duo.

Grammar fix en route ("when answering a question obviously doesn't" →
"when a question obviously doesn't"); "(glab duo cli)" dropped (the body
carries the exact command).

### gdk (43 words, in-band but not trigger-style; typo "how feature works")

> Use the local GitLab Development Kit (GDK) — a folder and utilities running most GitLab production systems. Use when testing against a local GitLab deployment or researching how a feature works in the monolith, AI Gateway, workhorse and other services.

### web-search (15, vague)

> Search the web — general queries, current events, documentation lookups, anything not answerable from local files or the repo. Use when a question needs information from the internet rather than the local context. Think Google Search for agents.

### tui-testing (19, terse)

> Run an interactive CLI/TUI app in tmux, send it input, and read its output. Use when you need to exercise an interactive terminal app — testing it, driving its prompts, or capturing what it renders.

## `pi/.pi/agent/AGENTS.md` trim (one concern, separate edit — owner decision)

The **Forbidden Git Operations** section restates the `git-guard`
extension's blocklist — a mechanism already enforced on every tool call
(principle 2: mechanism over prose). But the *reason* ("can destroy your
or other agents' uncommitted work") also covers ops the extension does not
block (`git checkout -- <file>`, `git restore`), so it stays. Proposed
replacement (8 → 5 lines, 57 → 54 total):

> ## Git discipline
>
> Destructive git ops can destroy your or other agents' uncommitted work — the `git-guard` extension blocks the common ones; apply the same caution to anything it doesn't block (e.g. `git checkout -- <file>`). `git commit` is allowed but only on request — don't commit unless asked. If a blocked op is genuinely needed, Tomas runs it himself in his terminal.

Everything else in the file is K: username, work context, marker-line
format (taught by prose, enforced by the task extension), task-state
protocol, `GIT_EDITOR=true` (prevents interactive hangs, non-inferable),
Orbit routing pointer.

## Purged-scope decision (finding 1) — owner decision

`pi/.pi/agent/purge/` (380K, ~16 skills + 8 extensions): **not scanned by
pi** (verified from the live session's 21-skill list — none from purge;
deleting it saves zero tokens), zero live references anywhere in the repo
or `~/.agents` content. Same-named skills (gdk, git-worktree, gitlab-api,
projects, wait-for, dotfiles) exist in newer form under
`agents/.agents/skills/`; but purge also holds content with **no live
replacement** (mr-issue-standards, windows-testing, work-context,
html-report, mermaid, native-web-search, shell-scripts,
terminal-screenshot, tmux-cli-testing, 8 extensions). Options: delete
(git history preserves everything; recommended — it is dead weight) or
keep as archive. No token impact either way — purely a tidiness call.

## Eval plan (hard budget: ~$5 total, owner directive 2026-11-09)

Per the frozen-eval lesson (nvim-theme, 2026-11-09): no full suites, no
gating runs. Each rewritten description gets the cheap version — 1–3
at-risk trigger cases per skill, run once on the fast default model
(~$0.05 per case, ~$0.60 for the ~12-case smoke set below), pass = load,
miss = revert that description. **The whole global-pass eval spend stays
under ~$5**; anything beyond the smoke set is deferred, not run.

Smoke set (terse, natural prompts; run from a scratch /tmp cwd so only
the global scopes are in play):

| case | prompt (abbrev) | expect |
|---|---|---|
| task-tabs-1 | "what's running in my task right now?" | load task-tabs, not task-management |
| task-tabs-2 | "clean up the tabs in this task session" | load task-tabs |
| task-mgmt-near | "create a new task for X" | load task-management, not task-tabs |
| web-browser-1 | "this page needs JS to render, read what it says" | load web-browser |
| downloads-near | "where's the screenshot I just took?" | load downloads, not web-browser |
| epub-1 | "turn this report into something I can read on the kobo" | load epub |
| review-depth-1 | "review MR 123, but first check whether it's even needed" | load review or review-depth |
| subagent-1 | "send duo to figure out why the lsp auth fails" | load subagent |
| gdk-1 | "my GDK postgres keeps crashlooping, help me debug" | load gdk |
| web-search-1 | "what's the latest release of kanata?" | load web-search |
| tui-testing-1 | "test the new fzf picker interactively before I commit" | load tui-testing |
| gitlab-api-1 | "list my gitlab todos" | load gitlab-api |

## Net effect if all land

Descriptions 5,836 → ~5,630 bytes (~−50 tok/session, every pi session);
AGENTS.md 57 → 54 lines; one cross-harness duplicate deleted (claude
gitlab-api, done); two broken symlinks fixed (done). Revert: each rewrite
is a one-file `git checkout --` of its SKILL.md.
