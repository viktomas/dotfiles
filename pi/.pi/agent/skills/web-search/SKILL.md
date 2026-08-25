---
name: web-search
description: use this skill when you need to search the web, think google search for agents
---

# Web Search

Use the `claude` CLI in headless mode. It searches the web and returns a
post-processed summary with source links. Typical query takes 30–60s, so set
your bash tool timeout to at least 180s.

```bash
claude -p "Search the web: <what to look up>. Purpose: <why you need it, so results are summarized for your goal>. Cite sources." --allowed-tools WebSearch WebFetch
```

Notes:
- Always pass `--allowed-tools WebSearch WebFetch` — without it the CLI answers
  from memory instead of searching, and unrestricted tools would need permissions.
- `WebFetch` lets it read a specific page; include the URL in the prompt when you
  already know where the answer lives.
- Add `--model sonnet` for cheaper/faster answers, `--model opus` for hard
  research questions. Default is fine for most searches.
- Ask for source URLs in the prompt; the output is markdown, safe to quote.
- Run from any directory; no state or setup needed.

Examples:

```bash
# straight lookup
claude -p "Search the web: latest stable Node.js version and release date. Cite sources." --allowed-tools WebSearch WebFetch

# targeted read of a known page
claude -p "Fetch https://nodejs.org/en/about/previous-releases and tell me the EOL date of Node 22." --allowed-tools WebSearch WebFetch
```
