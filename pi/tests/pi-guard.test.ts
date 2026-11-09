import assert from 'node:assert/strict';
import { test } from 'node:test';

import piGuard, { isMisePiEntry, piInstallMismatch } from '../.pi/agent/extensions/pi-guard.ts';

type Handler = (e: any, ctx: any) => unknown;

const BACKEND = 'npm-earendil-works-pi-coding-agent';

test('isMisePiEntry accepts the mise npm backend bin', () => {
  // The path `which pi` resolves to inside a mise-activated project.
  assert.equal(
    isMisePiEntry(
      `/Users/tomas/.local/share/mise/installs/${BACKEND}/latest/node_modules/.bin/pi`,
      BACKEND,
    ),
    true,
  );
  // Resolved through the versioned .mise dir, e.g. after realpath.
  assert.equal(
    isMisePiEntry(
      `/Users/tomas/.local/share/mise/installs/${BACKEND}/1.5.0/node_modules/.mise/@earendil-works+pi-coding-agent@1.5.0/node_modules/@earendil-works/pi-coding-agent/dist/cli.js`,
      BACKEND,
    ),
    true,
  );
});

test('isMisePiEntry rejects the paths that caused the 2026-11-09 incident', () => {
  // A stale global npm install under a mise node version shadows the backend.
  assert.equal(
    isMisePiEntry('/Users/tomas/.local/share/mise/installs/node/22.22.1/bin/pi', BACKEND),
    false,
  );
  assert.equal(isMisePiEntry('/usr/local/bin/pi', BACKEND), false);
  assert.equal(isMisePiEntry('/home/tomas/dev/pi/dist/cli.js', BACKEND), false);
});

test('isMisePiEntry matches path segments, not substrings', () => {
  assert.equal(isMisePiEntry(`/opt/x-${BACKEND}-y/bin/pi`, BACKEND), false);
  // `installs` without the mise parent is not a mise install dir.
  assert.equal(isMisePiEntry(`/usr/lib/installs/${BACKEND}/bin/pi`, BACKEND), false);
});

test('isMisePiEntry honours a custom backend and rejects empties', () => {
  assert.equal(
    isMisePiEntry('/home/u/.local/share/mise/installs/npm-my-pi/latest/bin/pi', 'npm-my-pi'),
    true,
  );
  assert.equal(isMisePiEntry('', BACKEND), false);
  assert.equal(isMisePiEntry('/x/mise/installs//bin/pi', ''), false);
  // Windows separators.
  assert.equal(
    isMisePiEntry(
      `C:\\Users\\u\\.local\\share\\mise\\installs\\${BACKEND}\\latest\\bin\\pi`,
      BACKEND,
    ),
    true,
  );
});

function loadGuard(): Map<string, Handler> {
  const handlers = new Map<string, Handler>();
  const pi = { on: (ev: string, h: Handler) => handlers.set(ev, h) };
  piGuard(pi as any);
  return handlers;
}

function envWith(overrides: Record<string, string | undefined>) {
  const saved: Record<string, string | undefined> = {};
  for (const k of Object.keys(overrides)) saved[k] = process.env[k];
  for (const [k, v] of Object.entries(overrides)) {
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
  return () => {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  };
}

test('session_start: wrong pi fails the session (UI: confirm then shutdown)', async () => {
  // In the test process argv[1] is the node test runner, not a mise pi
  // entry — exactly the mismatch the guard exists for.
  const restore = envWith({ PI_GUARD_ANY: undefined, PI_GUARD_BACKEND: undefined });
  try {
    const events: string[] = [];
    const ctx = {
      hasUI: true,
      ui: {
        confirm: async (title: string, msg: string) => {
          events.push(`confirm:${title}`);
          return true;
        },
        notify: (msg: string, kind: string) => events.push(`notify:${kind}:${msg}`),
      },
      shutdown: () => events.push('shutdown'),
    };
    await loadGuard().get('session_start')!({}, ctx);
    assert.equal(events.length, 2);
    assert.equal(events[0], 'confirm:pi-guard: wrong pi — exiting');
    assert.equal(events[1], 'shutdown');
  } finally {
    restore();
  }
});

test('session_start: wrong pi fails the session (headless: stderr + exit 1)', async () => {
  const restore = envWith({ PI_GUARD_ANY: undefined, PI_GUARD_BACKEND: undefined });
  const origExit = process.exit;
  const exits: number[] = [];
  (process as any).exit = ((code?: number) => {
    exits.push(code ?? 0);
  }) as never;
  try {
    const events: string[] = [];
    const ctx = {
      hasUI: false,
      ui: { notify: (msg: string, kind: string) => events.push(`notify:${kind}:${msg}`) },
      shutdown: () => events.push('shutdown'),
    };
    await loadGuard().get('session_start')!({}, ctx);
    // No confirm/dialog path, no graceful shutdown: a hard exit.
    assert.deepEqual(events, []);
    assert.deepEqual(exits, [1]);
  } finally {
    (process as any).exit = origExit;
    restore();
  }
});

test('session_start: confirm failure falls back to notify + shutdown', async () => {
  const restore = envWith({ PI_GUARD_ANY: undefined, PI_GUARD_BACKEND: undefined });
  try {
    const events: string[] = [];
    const ctx = {
      hasUI: true,
      ui: {
        confirm: async () => {
          throw new Error('old pi without confirm');
        },
        notify: (msg: string, kind: string) => events.push(`notify:${kind}:${msg}`),
      },
      shutdown: () => events.push('shutdown'),
    };
    await loadGuard().get('session_start')!({}, ctx);
    assert.equal(events.length, 2);
    assert.match(events[0]!, /^notify:error:pi-guard: /);
    assert.equal(events[1], 'shutdown');
  } finally {
    restore();
  }
});

test('session_start: mise pi (or PI_GUARD_ANY) is let through', async () => {
  const restore = envWith({ PI_GUARD_ANY: '1' });
  try {
    const events: string[] = [];
    const ctx = {
      hasUI: true,
      ui: { notify: (msg: string, kind: string) => events.push(`notify:${kind}:${msg}`) },
      shutdown: () => events.push('shutdown'),
    };
    await loadGuard().get('session_start')!({}, ctx);
    assert.deepEqual(events, []);
  } finally {
    restore();
  }
});

test('piInstallMismatch: PI_GUARD_BACKEND redirects the check', () => {
  const restore = envWith({
    PI_GUARD_ANY: undefined,
    PI_GUARD_BACKEND: 'npm-my-pi',
  });
  try {
    // The test runner's entry is not under mise/installs, so it fails the
    // check — but the message must name the configured backend, proving the
    // override is what the matcher used.
    assert.match(piInstallMismatch()!, /mise install \(npm-my-pi\): /);
  } finally {
    restore();
  }
});
