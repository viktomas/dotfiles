---
name: web-search
description: use this skill when you need to search the web, think google search for agents
---

# Web Search

Run from this skill directory (set your bash tool timeout to at least 200s — the
web_search tool runs multi-step and a query can take 2+ minutes):

```bash
node search.mjs "<what to look up (the search terms)>" --purpose "<why you need it, so results are summarized for your goal>"
```

The skill uses Anthropic's search API and LLM will post-process the reslts to give you summary.

Notes:
- `--timeout` is in **milliseconds** (default 300000 = 5 min); it is the internal API
  wait, separate from your bash tool timeout. Don't set it to a small number.
- Transient network / 429 / 5xx errors are retried automatically.
- "server tool use limit exceeded" in the output means Anthropic rate-limited the
  web_search tool (too many searches in a short window); wait a bit and retry.

Use this only when absolutely necessary: If you need to white/black list domains or set result location, run the `node search.mjs` without args to see the script help.
