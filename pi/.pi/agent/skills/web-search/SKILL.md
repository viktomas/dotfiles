---
name: web-search
description: use this skill when you need to search the web, think google search for agents
---

# Web Search

Run from this skill directory (set bash timeout to at least 90s):

```bash
node search.mjs "<what to look up (the search terms)>" --purpose "<why you need it, so results are summarized for your goal>"
```

The skill uses Anthropic's search API and LLM will post-process the reslts to give you summary.

Use this only when absolutely necessary: If you need to white/black list domains or set result location, run the `node search.mjs` without args to see the script help.
