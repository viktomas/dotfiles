/**
 * Auto-trust worktree projects, and keep a pi blocked on the built-in trust
 * prompt visible to the attention system.
 *
 * Trusting: any project whose cwd lives under one of the worktree roots
 * listed in the $G_FOLDER_ALIASES env var (format:
 * "alias:/path,alias:/path,...") is trusted automatically. This way every
 * new git worktree created under those roots is trusted without having to
 * add each one to ~/.pi/agent/trust.json.
 *
 * The trust bell: the built-in trust prompt runs BEFORE session_start, so a
 * pi blocked on it has no fleet live record (fleet.ts writes one at
 * session_start), no task.ts registry entry and no OSC 7501 status — an
 * unregistered ghost that `task queue`, the picker, `task fleet` and
 * zellij's attention markers all ignore. A review pi on a fresh worktree
 * once sat on that prompt for 24 minutes before anyone noticed (task
 * fix-trust-request-s-l99fl). When this extension is about to let the
 * built-in prompt show — a TUI pi on a task, no saved trust decision
 * covering the cwd, defaultProjectTrust "ask" — it registers the pid as
 * waiting (gate "prompt", note "pi trust request: <cwd>"), the same trick
 * task.ts uses for its own start-confirm dialog. session_start clears the
 * entry (idle) unless something else took it over; agent_start then flips
 * it to working. A prompt cancelled with escape kills pi, and `task agent`
 * prunes dead pids by itself.
 *
 * Print/RPC subagents never see a prompt (pi silently skips the protected
 * resources), and task-less pis (main session, kickoff) have no registry to
 * ring — both stay out of this.
 */

import { readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import type { ExtensionAPI, ProjectTrustEventResult } from "@earendil-works/pi-coding-agent";

function parseRoots(): string[] {
	const raw = process.env.G_FOLDER_ALIASES ?? "";
	return raw
		.split(",")
		.map((entry) => entry.slice(entry.indexOf(":") + 1).trim())
		.filter((path) => path.length > 0)
		.map((path) => {
			try {
				return realpathSync(resolve(path));
			} catch {
				return resolve(path);
			}
		});
}

function isInside(root: string, target: string): boolean {
	const rel = relative(root, target);
	return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

/** Canonical path when it exists, the input otherwise. */
function canonical(path: string): string {
	try {
		return realpathSync(path);
	} catch {
		return path;
	}
}

/**
 * True when ~/.pi/agent/trust.json holds a decision for dir or any of its
 * parents: pi walks the cwd and its parents and the closest decision
 * applies, so any covering entry (trusted or declined) means no built-in
 * prompt. Unreadable file = no decision = the prompt shows.
 */
function savedDecisionCovers(dir: string): boolean {
	let saved: Record<string, unknown>;
	try {
		saved = JSON.parse(readFileSync(join(homedir(), ".pi", "agent", "trust.json"), "utf8"));
	} catch {
		return false;
	}
	for (let d = canonical(dir); ; d = dirname(d)) {
		if (d in saved) return true;
		if (dirname(d) === d) return false;
	}
}

/**
 * defaultProjectTrust from ~/.pi/agent/settings.json, "ask" when unset:
 * only "ask" shows the built-in prompt ("always" trusts, "never" declines,
 * both without asking).
 */
function defaultProjectTrust(): string {
	try {
		const settings = JSON.parse(
			readFileSync(join(homedir(), ".pi", "agent", "settings.json"), "utf8"),
		) as { defaultProjectTrust?: string };
		return settings.defaultProjectTrust ?? "ask";
	} catch {
		return "ask";
	}
}

/** This pi's zellij pane ("terminal_<n>"), for the registry entry. */
function pane(): string | undefined {
	return process.env.ZELLIJ_PANE_ID ? `terminal_${process.env.ZELLIJ_PANE_ID}` : undefined;
}

/** `task agent <state>` args for a write from this process. */
function agentArgs(state: "waiting" | "idle", extra: string[] = []): string[] {
	const args = ["agent", state, "--pid", String(process.pid)];
	const p = pane();
	if (p) args.push("--pane", p);
	return [...args, ...extra];
}

/** Run `task` for the registry; best effort, never throws. */
async function task(pi: ExtensionAPI, args: string[]): Promise<{ code: number; stdout: string } | undefined> {
	try {
		return await pi.exec("task", args, { timeout: 5000 });
	} catch {
		return undefined;
	}
}

export default function (pi: ExtensionAPI) {
	const roots = parseRoots();
	/** Set while this process's registry entry is the trust bell. */
	let trustBellRung = false;

	pi.on("project_trust", async (event, ctx): Promise<ProjectTrustEventResult> => {
		const cwd = canonical(resolve(event.cwd));

		if (roots.some((root) => isInside(root, cwd))) {
			return { trusted: "yes" };
		}

		// About to let the built-in prompt show? Ring the bell first (see
		// header): a task pi blocked here is invisible everywhere else.
		const hasUI = (ctx as { hasUI?: boolean } | undefined)?.hasUI === true;
		if (
			hasUI &&
			!trustBellRung &&
			process.env.TASK_ID &&
			!savedDecisionCovers(cwd) &&
			defaultProjectTrust() === "ask"
		) {
			trustBellRung = true;
			await task(pi, agentArgs("waiting", ["--gate", "prompt", "--note", `pi trust request: ${cwd}`]));
		}
		return { trusted: "undecided" };
	});

	pi.on("session_start", async () => {
		// The prompt is answered (or never showed): clear the bell entry —
		// but only while it is still ours, because task.ts's start-confirm
		// dialog may have replaced it with its own waiting gate in the
		// meantime. A bare pi then idles at its prompt until agent_start
		// (the first prompt) flips the entry to working.
		if (!trustBellRung || !process.env.TASK_ID) return;
		trustBellRung = false;
		const result = await task(pi, ["show", process.env.TASK_ID, "--json"]);
		if (!result || result.code !== 0) return;
		try {
			const entry = (
				(JSON.parse(result.stdout) as { agents?: Record<string, { note?: string }> }).agents ?? {}
			)[String(process.pid)];
			if (entry?.note?.startsWith("pi trust request")) {
				await task(pi, agentArgs("idle"));
			}
		} catch {
			// unreadable answer: leave the entry; a dead pid is pruned anyway
		}
	});
}
