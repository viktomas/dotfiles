/**
 * Last reply age
 *
 * Shows a dim gray "● last reply 2h ago" indicator on the footer status line,
 * after the task name (key sorts after "task"), so that when I resume a
 * session I can immediately spot when the previous run paused on its last
 * LLM response.
 *
 * - `session_start` (startup/resume/new): timestamp of the last assistant
 *   message on the current branch, from the persisted session entries.
 * - `agent_settled`: timestamp of the finished run (also covers aborts —
 *   that's still "when the session paused").
 * - A 30s interval keeps the "ago" text current while idle.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Sorts after the "task" status key, so on the shared footer status line
// (statuses are joined sorted by key) the task name leads, followed by this
// indicator: "📋 <task name> ● last reply 2h ago".
const STATUS_KEY = "task-last-reply";
const REFRESH_MS = 30_000;

function formatAgo(ms: number): string {
	const s = Math.max(0, Math.floor(ms / 1000));
	if (s < 60) return `${s}s ago`;
	const m = Math.floor(s / 60);
	if (m < 60) return `${m}m ago`;
	const h = Math.floor(m / 60);
	if (h < 24) return `${h}h ago`;
	return `${Math.floor(h / 24)}d ago`;
}

/** Timestamp (ms) of the last assistant message on the current branch. */
function lastAssistantAt(ctx: ExtensionContext): number | undefined {
	const entries = ctx.sessionManager.getBranch();
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (entry.type === "message" && entry.message.role === "assistant") {
			const ts = entry.message.timestamp;
			return typeof ts === "number" ? ts : Date.parse(entry.timestamp);
		}
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	let lastAt: number | undefined;
	let timer: ReturnType<typeof setInterval> | undefined;
	let currentCtx: ExtensionContext | undefined;

	const update = () => {
		if (!currentCtx || currentCtx.mode !== "tui") return;
		if (lastAt === undefined) {
			currentCtx.ui.setStatus(STATUS_KEY, undefined);
		} else {
			const theme = currentCtx.ui.theme;
			const circle = theme.fg("dim", "●");
			const text = theme.fg("dim", `last reply ${formatAgo(Date.now() - lastAt)}`);
			currentCtx.ui.setStatus(STATUS_KEY, `${circle} ${text}`);
		}
	};

	const stopTimer = () => {
		if (timer) clearInterval(timer);
		timer = undefined;
	};

	pi.on("session_start", (_event, ctx) => {
		currentCtx = ctx;
		lastAt = lastAssistantAt(ctx);
		update();
		stopTimer();
		if (ctx.mode === "tui") {
			timer = setInterval(update, REFRESH_MS);
		}
	});

	pi.on("agent_settled", (_event, ctx) => {
		currentCtx = ctx;
		lastAt = Date.now();
		update();
	});

	pi.on("session_shutdown", (_event, ctx) => {
		stopTimer();
		lastAt = undefined;
		currentCtx = undefined;
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
