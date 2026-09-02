/**
 * Inline diagrams
 *
 * Turns fenced ```d2 and ```svg blocks in assistant messages into images
 * rendered in the transcript (Kitty graphics protocol), so a report can be read
 * in the terminal instead of a browser.
 *
 * - `message_end` — every complete d2/svg block is rendered to PNG with the
 *   `diagram` helper script and appended as a custom entry (TUI only, no image
 *   tokens in context).
 * - markdown transformer — the raw block is replaced by a one-line marker, so
 *   the prose stays readable. The source itself stays untouched in the session,
 *   so a later session can still re-render it.
 * - render failures are sent back to the LLM as a custom message, so the agent
 *   sees the d2 compiler error and can fix the diagram.
 */

import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getCellDimensions, Image, Text } from "@earendil-works/pi-tui";

const execFileAsync = promisify(execFile);

const DIAGRAM_BIN = join(homedir(), ".pi", "agent", "skills", "report", "scripts", "diagram");
const CACHE_DIR = join(homedir(), ".cache", "pi", "diagrams");
const RENDER_TIMEOUT_MS = 20_000;
/** Display box. Width is clamped to the transcript width, so this only caps very wide images. */
const MAX_WIDTH_CELLS = 160;
const MAX_HEIGHT_CELLS = 45;
/** Supersampling: render above the display resolution so the terminal downscale stays crisp. */
const OVERSAMPLE = 2;
const MAX_PX = 3000;

/** Pixel size to rasterise at, matching the cells the image will occupy on screen. */
function targetPixels(): { width: number; height: number } {
	const cell = getCellDimensions();
	const width = Math.round(MAX_WIDTH_CELLS * (cell.widthPx || 10) * OVERSAMPLE);
	const height = Math.round(MAX_HEIGHT_CELLS * (cell.heightPx || 20) * OVERSAMPLE);
	return { width: Math.min(MAX_PX, width), height: Math.min(MAX_PX, height) };
}

/** ```d2 / ```svg fenced block, with its closing fence. */
const FENCE_RE = /^([ \t]*)(`{3,}|~{3,})[ \t]*(d2|svg)[^\n]*\n([\s\S]*?)^[ \t]*\2[ \t]*$/gm;

type Block = { lang: "d2" | "svg"; source: string; hash: string };

type DiagramEntry = {
	/** 1-based position within the assistant message. */
	index: number;
	lang: "d2" | "svg";
	/** Absolute path of the rendered PNG in the cache dir. */
	path: string;
};

function blocks(markdown: string): Block[] {
	const found: Block[] = [];
	for (const match of markdown.matchAll(FENCE_RE)) {
		const source = match[4] ?? "";
		if (!source.trim()) continue;
		found.push({
			lang: match[3] as "d2" | "svg",
			source,
			hash: createHash("sha1").update(`${match[3]}\n${source}`).digest("hex").slice(0, 16),
		});
	}
	return found;
}

function assistantText(content: unknown): string {
	if (!Array.isArray(content)) return "";
	return content
		.filter((part): part is { type: "text"; text: string } => (part as { type?: string })?.type === "text")
		.map((part) => part.text)
		.join("\n");
}

/** Render a block to PNG in the cache dir. Returns the path, or throws with the compiler error. */
async function render(block: Block): Promise<string> {
	mkdirSync(CACHE_DIR, { recursive: true });
	const px = targetPixels();
	const png = join(CACHE_DIR, `${block.hash}-${px.width}x${px.height}.png`);
	if (existsSync(png)) return png;

	const src = join(tmpdir(), `pi-diagram-${block.hash}.${block.lang}`);
	writeFileSync(src, block.source);
	try {
		await execFileAsync(
			DIAGRAM_BIN,
			[src, "-o", png, "-w", String(px.width), "-H", String(px.height)],
			{ timeout: RENDER_TIMEOUT_MS },
		);
	} catch (error) {
		const err = error as { stderr?: string; message?: string };
		const raw = (err.stderr || err.message || "unknown error").trim();
		// Drop the helper's own summary line and the temp path noise around the real error.
		const cleaned = raw
			.split("\n")
			.filter((line) => !line.startsWith("diagram: "))
			.join("\n")
			.replace(/\S*pi-diagram-[0-9a-f]+\.(?:d2|svg)/g, "<block>");
		throw new Error(cleaned.trim() || raw);
	}
	return png;
}

export default function diagrams(pi: ExtensionAPI) {
	/** Blocks that already failed once — don't wake the agent for the same source twice. */
	const reported = new Set<string>();
	/** Hashes that failed to render; their source stays visible instead of becoming a marker. */
	const failed = new Set<string>();

	pi.registerEntryRenderer<DiagramEntry>("diagram", (entry, _options, theme) => {
		const data = entry.data;
		if (!data) return undefined;
		const label = `diagram ${data.index} (${data.lang})`;
		try {
			const base64 = readFileSync(data.path).toString("base64");
			return new Image(
				base64,
				"image/png",
				{ fallbackColor: (str: string) => theme.fg("dim", str) },
				{ maxWidthCells: MAX_WIDTH_CELLS, maxHeightCells: MAX_HEIGHT_CELLS, filename: label },
			);
		} catch {
			return new Text(theme.fg("dim", `[${label}: image no longer cached]`), 0, 0);
		}
	});

	// Replace the source of rendered blocks with a marker; the images follow the message.
	pi.registerMarkdownTransformer((markdown, { messageType }) => {
		if (messageType !== "assistant") return markdown;
		let index = 0;
		return markdown.replace(FENCE_RE, (raw, indent: string, _fence, lang: string, source: string) => {
			if (!source.trim()) return raw;
			index += 1;
			const hash = createHash("sha1").update(`${lang}\n${source}`).digest("hex").slice(0, 16);
			if (failed.has(hash)) return raw;
			return `${indent}◈ diagram ${index} (${lang})`;
		});
	});

	pi.on("message_end", (event, ctx) => {
		if (event.message.role !== "assistant") return;

		const found = blocks(assistantText(event.message.content));
		if (found.length === 0) return;

		// Detached on purpose: while `message_end` listeners run, the TUI still holds the
		// streaming component and splices new entries *above* it. Handing control back
		// first lets the message settle, so the images land under it.
		void processBlocks(found, ctx);
	});

	async function processBlocks(found: Block[], ctx: { ui: { notify: (message: string, level: string) => void } }) {
		await new Promise((resolve) => setTimeout(resolve, 0));

		const failures: string[] = [];
		let fresh = false;

		for (const [position, block] of found.entries()) {
			try {
				const path = await render(block);
				pi.appendEntry<DiagramEntry>("diagram", { index: position + 1, lang: block.lang, path });
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				failures.push(`diagram ${position + 1} (${block.lang}): ${message}`);
				failed.add(block.hash);
				if (!reported.has(block.hash)) {
					reported.add(block.hash);
					fresh = true;
				}
			}
		}

		if (failures.length === 0) return;

		ctx.ui.notify(`${failures.length} diagram(s) failed to render`, "warning");
		pi.sendMessage(
			{
				customType: "diagram",
				content: [
					"Some diagrams in your last message did not render:",
					"",
					...failures.map((failure) => `- ${failure}`),
					"",
					fresh
						? "Fix the source and repost the corrected block(s)."
						: "Same failure as before — fix it differently or drop the diagram.",
				].join("\n"),
				display: true,
			},
			{ deliverAs: "followUp", triggerTurn: fresh },
		);
	}
}
