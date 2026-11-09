/**
 * Pi install guard (global)
 *
 * Fails a session at startup when this pi is not the mise-managed install:
 * `process.argv[1]` must run through mise/installs/<backend>/ (the npm
 * backend that owns pi). A pi resolved from anywhere else is an accident
 * waiting to happen — most painfully a stale global npm install under a
 * mise node version, whose bin dir shadows the backend on PATH inside
 * node-pinned projects (2026-11-09 incident: pi 0.76.0 under node/22.22.1
 * shadowed the 1.5.0 backend in gitlab-lsp worktrees; it fired agent_start
 * but never agent_settled, so task registries stuck at "working" for the
 * life of the pid, and it lacked pi.getSettings, breaking bash-timeout and
 * with it every bash call). Old pis accept `pi.on` for events they never
 * emit, so nothing fails loudly — this guard is the loud failure.
 *
 * - Default backend: npm-earendil-works-pi-coding-agent.
 *   PI_GUARD_BACKEND overrides (path-segment match, not substring).
 * - PI_GUARD_ANY=1 skips the check (e.g. running pi from a checkout on
 *   purpose).
 * - No entry script (exotic runtime) can't be a shadowed install: allowed.
 *
 * Uses only extension APIs old pis also have (session_start, ui.notify,
 * ui.confirm, ctx.shutdown), and user-facing reporting is best-effort: a
 * broken pi must never be kept alive by its own error reporting. Headless
 * modes (print/json/rpc) never bind a shutdown action — ctx.shutdown() is a
 * no-op there — so the guard hard-exits instead.
 */

import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const DEFAULT_BACKEND = 'npm-earendil-works-pi-coding-agent';

/**
 * True when an executed entry script path (process.argv[1]) belongs to the
 * mise-managed pi install: it must run through mise/installs/<backend>/.
 * Path-segment matching, not substring, so a backend name can't match
 * elsewhere in the path. Tested by pi-guard.test.ts.
 */
export function isMisePiEntry(entry: string, backend: string): boolean {
  if (!entry || !backend) return false;
  const segs = entry.split(/[\\/]+/).filter((s) => s !== '');
  const i = segs.indexOf('installs');
  return i >= 1 && segs[i - 1] === 'mise' && segs[i + 1] === backend;
}

/**
 * Why this pi is not the mise-managed install, or undefined when it is — or
 * when it can't be told or PI_GUARD_ANY allows it.
 */
export function piInstallMismatch(): string | undefined {
  if (process.env.PI_GUARD_ANY) return undefined;
  const backend = process.env.PI_GUARD_BACKEND || DEFAULT_BACKEND;
  const entry = process.argv[1] ?? '';
  if (!entry) return undefined;
  if (isMisePiEntry(entry, backend)) return undefined;
  return `pi-guard: this pi is not the mise install (${backend}): ${entry}`;
}

export default function (pi: ExtensionAPI) {
  pi.on('session_start', async (_event, ctx) => {
    const wrongPi = piInstallMismatch();
    if (!wrongPi) return;
    if (ctx.hasUI) {
      // Blocking dialog so the reason is guaranteed seen before the exit
      // (a notification can flash by as the TUI tears down). Falls back
      // to a plain shutdown on old pis without confirm.
      try {
        await ctx.ui.confirm(
          'pi-guard: wrong pi — exiting',
          `${wrongPi}\n\nThis session cannot work correctly; it exits when you dismiss this.`,
        );
      } catch {
        try {
          ctx.ui.notify(`${wrongPi}; exiting`, 'error');
        } catch {
          // reporting must never keep a broken session alive
        }
      }
      ctx.shutdown();
    } else {
      // Print/json/rpc: ctx.shutdown() is not bound there, so exit hard.
      process.stderr.write(`${wrongPi}; exiting\n`);
      process.exit(1);
    }
  });
}
