---
name: native-web-search
description: "Trigger native web search. Use when you need quick internet research with concise summaries and full source URLs."
---

# Native Web Search

Use this skill to run a **fast model with native web search enabled** and get a concise research summary with explicit full URLs.

## Script

- `search.mjs`

## Usage

Run from this skill directory:

```bash
node search.mjs "<what to search>" --purpose "<why you need this>"
```

**Important:** When running `search.mjs` via a bash tool, set the bash tool's timeout to at least 90 seconds. The default 30s is too short and causes the command to be killed before results come back.

Examples:

```bash
node search.mjs "latest python release" --purpose "update dependency notes"
node search.mjs "vite 7 breaking changes" --purpose "prepare migration checklist"
node search.mjs "best restaurants" --location "San Francisco, California, US"
node search.mjs "kubernetes docs" --allowed-domains kubernetes.io,docs.k8s.io
```

Optional flags:

- `--provider openai-codex|anthropic`
- `--model <model-id>`
- `--timeout <ms>`
- `--json`
- `--allowed-domains d1,d2` — only include results from these domains
- `--blocked-domains d1,d2` — exclude results from these domains
- `--location "City, Region, Country"` — localize search results

## Output expectations

The script instructs the model to:
- search the internet for the requested topic
- provide a concise summary for the given purpose
- include full canonical URLs (`https://...`) for each key finding
- highlight disagreements between sources

## Implementation details

- Uses Anthropic's `web_search_20250305` tool
- Default Anthropic model: `claude-sonnet-4-6`
- Max 5 searches per request
- Domain filtering and location are passed directly in the tool definition
- Location format: `"City, Region, Country"` — country must be a supported code (e.g. `US`, `GB`, `DE`; not all codes work)

## Notes

- No extra npm install is required.
- If module resolution fails, set `PI_AI_MODULE_PATH` to `@mariozechner/pi-ai`'s `dist/index.js` path.
