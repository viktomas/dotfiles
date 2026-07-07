#!/usr/bin/env node

// Bare-bones web search via Anthropic's web_search tool.
// Requires ANTHROPIC_API_KEY in the environment. No dependencies.

const DEFAULT_MODEL = "claude-sonnet-5";

function parseArgs(argv) {
	const out = {
		model: DEFAULT_MODEL,
		purpose: "general research support",
		timeoutMs: 120000,
		json: false,
		help: false,
		query: "",
		allowedDomains: undefined,
		blockedDomains: undefined,
		location: undefined,
	};

	const positional = [];
	const takeValue = (arg, i, prefix) =>
		arg.startsWith(`${prefix}=`) ? arg.slice(prefix.length + 1) : argv[i + 1];

	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg === "--help" || arg === "-h") {
			out.help = true;
		} else if (arg === "--json") {
			out.json = true;
		} else if (arg === "--model" || arg.startsWith("--model=")) {
			out.model = takeValue(arg, i, "--model") || out.model;
			if (!arg.includes("=")) i++;
		} else if (arg === "--purpose" || arg.startsWith("--purpose=")) {
			out.purpose = takeValue(arg, i, "--purpose") || out.purpose;
			if (!arg.includes("=")) i++;
		} else if (arg === "--timeout" || arg.startsWith("--timeout=")) {
			out.timeoutMs = Math.max(1000, Number(takeValue(arg, i, "--timeout") || out.timeoutMs));
			if (!arg.includes("=")) i++;
		} else if (arg === "--allowed-domains" || arg.startsWith("--allowed-domains=")) {
			out.allowedDomains = (takeValue(arg, i, "--allowed-domains") || "")
				.split(",").map((d) => d.trim()).filter(Boolean);
			if (!arg.includes("=")) i++;
		} else if (arg === "--blocked-domains" || arg.startsWith("--blocked-domains=")) {
			out.blockedDomains = (takeValue(arg, i, "--blocked-domains") || "")
				.split(",").map((d) => d.trim()).filter(Boolean);
			if (!arg.includes("=")) i++;
		} else if (arg === "--location" || arg.startsWith("--location=")) {
			out.location = takeValue(arg, i, "--location") || undefined;
			if (!arg.includes("=")) i++;
		} else {
			positional.push(arg);
		}
	}

	out.query = positional.join(" ").trim();
	return out;
}

function usage() {
	return `Usage:
  node search.mjs "<query>" [--purpose "<why>"] [--model <id>] [--json] [--timeout <ms>]
    [--allowed-domains d1,d2] [--blocked-domains d1,d2] [--location "City, Region, Country"]

Requires ANTHROPIC_API_KEY in the environment.

Examples:
  node search.mjs "latest python release" --purpose "update dependency notes"
  node search.mjs "vite 7 breaking changes" --json
  node search.mjs "best restaurants" --location "San Francisco, California, US"`;
}

function buildUserPrompt(query, purpose) {
	return `Search the internet for: ${query}\n\nPurpose: ${purpose}\n\nReturn a concise research summary with:\n- 3 to 7 key findings\n- for every finding: title, why it matters for this purpose, and a full canonical URL (https://...)\n- if multiple sources disagree, call that out\n- finish with a short recommendation on which source(s) to trust first.`;
}

function buildSystemPrompt() {
	return "You are a fast web research assistant. Always produce practical summaries and include full source URLs (no shortened links).";
}

function parseLocation(locationStr) {
	if (!locationStr) return undefined;
	const parts = locationStr.split(",").map((s) => s.trim()).filter(Boolean);
	const loc = { type: "approximate" };
	if (parts[0]) loc.city = parts[0];
	if (parts[1]) loc.region = parts[1];
	if (parts[2]) loc.country = parts[2];
	return loc;
}

async function runSearch({ model, apiKey, query, purpose, timeoutMs, allowedDomains, blockedDomains, location }) {
	const toolDef = { type: "web_search_20260318", name: "web_search", max_uses: 5 };
	if (allowedDomains?.length) toolDef.allowed_domains = allowedDomains;
	if (blockedDomains?.length) toolDef.blocked_domains = blockedDomains;
	const userLocation = parseLocation(location);
	if (userLocation) toolDef.user_location = userLocation;

	const body = {
		model,
		max_tokens: 1800,
		system: buildSystemPrompt(),
		tools: [toolDef],
		messages: [{ role: "user", content: buildUserPrompt(query, purpose) }],
	};

	const signal = AbortSignal.timeout ? AbortSignal.timeout(timeoutMs) : undefined;

	const res = await fetch("https://api.anthropic.com/v1/messages", {
		method: "POST",
		headers: {
			"x-api-key": apiKey,
			"anthropic-version": "2023-06-01",
			"content-type": "application/json",
			accept: "application/json",
		},
		body: JSON.stringify(body),
		signal,
	});

	const payload = await res.text();
	if (!res.ok) {
		throw new Error(`Anthropic request failed (${res.status}): ${payload}`);
	}

	let parsed;
	try {
		parsed = JSON.parse(payload);
	} catch {
		throw new Error("Anthropic returned non-JSON response");
	}

	const text = (parsed.content || [])
		.filter((item) => item.type === "text" && typeof item.text === "string")
		.map((item) => item.text)
		.join("\n\n")
		.trim();

	if (!text) {
		throw new Error("Anthropic returned no text content");
	}

	return text;
}

async function main() {
	const args = parseArgs(process.argv.slice(2));
	if (args.help || !args.query) {
		console.error(usage());
		process.exit(args.help ? 0 : 1);
	}

	const apiKey = process.env.ANTHROPIC_API_KEY;
	if (!apiKey) {
		throw new Error("ANTHROPIC_API_KEY is not set in the environment.");
	}

	const text = await runSearch({
		model: args.model,
		apiKey,
		query: args.query,
		purpose: args.purpose,
		timeoutMs: args.timeoutMs,
		allowedDomains: args.allowedDomains,
		blockedDomains: args.blockedDomains,
		location: args.location,
	});

	if (args.json) {
		console.log(JSON.stringify({ model: args.model, query: args.query, purpose: args.purpose, result: text }, null, 2));
		return;
	}

	console.log(`Model: ${args.model}`);
	console.log("");
	console.log(text);
}

main().catch((err) => {
	console.error(`Error: ${err?.message || err}`);
	process.exit(1);
});
