---
name: tmux-cli-testing
description: Test interactive CLI applications using tmux sessions. Provides a Playwright-like API for terminal interactions including sending keys, waiting for output patterns, and capturing terminal content. Use when writing e2e tests for terminal-based applications.
---

# Testing Interactive CLI Applications with Tmux

This skill provides a pattern for testing interactive CLI applications using tmux sessions. The approach creates isolated tmux sessions to run CLI commands and provides a clean API for interacting with them programmatically.

## Overview

The `TmuxTerminalTest` class wraps tmux sessions to provide:
- **Isolated test environments** - Each test runs in its own tmux session
- **Playwright-like API** - Familiar patterns for waiting, typing, and asserting
- **Output capture** - Get terminal output with or without ANSI codes
- **Special key support** - Send arrow keys, Ctrl+C, Enter, etc.
- **Debugging support** - Attach to sessions for interactive debugging

## Key Concepts

### Why Tmux?

Tmux provides:
1. **Real terminal emulation** - Tests run in actual terminal environments
2. **Session management** - Create, control, and destroy sessions programmatically
3. **Output capture** - Read terminal buffer content at any time
4. **Input simulation** - Send keys and text as if a user typed them

### Architecture

```
Test Code → TmuxTerminalTest → Tmux Session → Your CLI App
     ↑                                              ↓
     └────────── Output Capture ──────────────────┘
```

## Usage Pattern

### Basic Test Structure

```typescript
import { TmuxTerminalTest } from './path/to/terminal_test_helper';

describe('My CLI App', () => {
  let terminal: TmuxTerminalTest;

  beforeEach(() => {
    // Start your CLI app in a tmux session
    terminal = new TmuxTerminalTest('node', ['dist/cli.js'], {
      cols: 80,      // Terminal width
      rows: 30,      // Terminal height
      timeout: 5000, // Default timeout for waitForMatch
      cwd: process.cwd(),
      env: { NODE_ENV: 'test' }
    });
  });

  afterEach(() => {
    // Clean up the tmux session
    terminal.cleanup();
  });

  it('should display welcome message', async () => {
    // Wait for a pattern to appear
    await terminal.waitForMatch(/Welcome to My CLI/);
    
    // Get the output
    const output = terminal.getOutput();
    expect(output).toContain('Welcome');
  });
});
```

### Common Test Patterns

#### 1. Wait for Output

```typescript
// Wait for a specific pattern
await terminal.waitForMatch(/Select an option:/);

// Wait with custom timeout
await terminal.waitForMatch(/Loading complete/, 10000);

// Capture matched groups
const match = await terminal.waitForMatch(/Version: ([\d.]+)/);
const version = match[1];
```

#### 2. Send Input

```typescript
// Type a line (includes Enter)
await terminal.writeLine('my-answer');

// Send special keys
terminal.sendKey('down');    // Navigate down
terminal.sendKey('down');    // Navigate down again
terminal.sendKey('enter');   // Select option

// Send Ctrl+C to interrupt
terminal.sendKey('ctrl+c');

// Available keys:
// escape, ctrl+c, ctrl+d, ctrl+o, enter, up, down,
// left, right, backspace, delete, home, end, tab
```

#### 3. Capture and Assert Output

```typescript
// Get clean output (ANSI codes stripped)
const output = terminal.getOutput();
expect(output).toContain('Success');

// Get raw output (with ANSI codes for testing colors/formatting)
const rawOutput = terminal.getRawOutput();
expect(rawOutput).toMatch(/\x1b\[32m.*Success/); // Green text
```

#### 4. Interactive Debugging

```typescript
it('should handle complex interaction', async () => {
  await terminal.waitForMatch(/Choose:/);
  
  // Drop into interactive mode to see what's happening
  // Uncomment when debugging:
  // terminal.attach();
  
  terminal.sendKey('down');
  await terminal.waitForMatch(/Selected: Option 2/);
});
```

### Real-World Example: Menu Navigation

```typescript
it('should navigate menu and select option', async () => {
  // Wait for menu to appear
  await terminal.waitForMatch(/Main Menu/);
  
  // Navigate to third option
  terminal.sendKey('down');
  terminal.sendKey('down');
  
  // Select it
  terminal.sendKey('enter');
  
  // Wait for confirmation
  await terminal.waitForMatch(/You selected: Option 3/);
  
  // Verify final state
  const output = terminal.getOutput();
  expect(output).toContain('Processing option 3');
});
```

### Real-World Example: Form Input

```typescript
it('should fill out a form', async () => {
  // Wait for first prompt
  await terminal.waitForMatch(/Enter your name:/);
  await terminal.writeLine('John Doe');
  
  // Next field
  await terminal.waitForMatch(/Enter your email:/);
  await terminal.writeLine('john@example.com');
  
  // Confirmation prompt
  await terminal.waitForMatch(/Is this correct\? \(y\/n\)/);
  await terminal.writeLine('y');
  
  // Verify success
  await terminal.waitForMatch(/Form submitted successfully/);
});
```

### Real-World Example: Testing Error Handling

```typescript
it('should handle invalid input', async () => {
  await terminal.waitForMatch(/Enter a number:/);
  
  // Try invalid input
  await terminal.writeLine('not-a-number');
  
  // Should show error
  await terminal.waitForMatch(/Error: Invalid number/);
  
  // Should re-prompt
  await terminal.waitForMatch(/Enter a number:/);
  
  // Try valid input
  await terminal.writeLine('42');
  
  // Should succeed
  await terminal.waitForMatch(/You entered: 42/);
});
```

## Constructor Options

```typescript
interface TmuxTerminalTestOptions {
  cols?: number;        // Terminal columns (default: 80)
  rows?: number;        // Terminal rows (default: 30)
  env?: Record<string, string>; // Environment variables
  cwd?: string;         // Working directory (default: process.cwd())
  timeout?: number;     // Default timeout for waitForMatch (default: 30000ms)
}
```

## API Reference

### Methods

#### `waitForMatch(pattern: RegExp, timeout?: number): Promise<RegExpMatchArray>`
Wait for a pattern to appear in the terminal output. Returns the match array.
Throws if timeout is reached.

#### `writeLine(text: string): Promise<void>`
Write text to the terminal and press Enter. Use for text input.

#### `sendKey(key: string): void`
Send a special key. Available keys:
- Navigation: `up`, `down`, `left`, `right`, `home`, `end`
- Editing: `backspace`, `delete`, `tab`, `enter`
- Control: `escape`, `ctrl+c`, `ctrl+d`, `ctrl+o`

#### `getOutput(): string`
Get the current terminal output with ANSI codes stripped.

#### `getRawOutput(): string`
Get the current terminal output with ANSI codes intact (for testing colors/formatting).

#### `cleanup(): void`
Kill the tmux session. Call this in `afterEach` to clean up resources.

#### `attach(): void`
Attach to the tmux session interactively. Useful for debugging tests.
Press `Ctrl+B` then `D` to detach.

#### `getSessionName(): string`
Get the unique session name (for debugging).

## Implementation Details

### Shell Escaping

The helper properly escapes command arguments using single quotes:
```typescript
// Input: my-arg with spaces and 'quotes'
// Output: 'my-arg with spaces and '\''quotes'\'''
```

This prevents shell injection and ensures arguments are passed correctly.

### Output Capture

Uses `tmux capture-pane -p -S 0` to capture only the visible screen (not scrollback).
This matches what users see and avoids historical output.

### Polling Strategy

`waitForMatch` polls every 100ms, which balances:
- Quick test execution
- Minimal CPU usage
- Reliable pattern detection

### Error Handling

On timeout, `waitForMatch` prints the full terminal output to help debugging:
```
=== TERMINAL OUTPUT (Timeout after 5000ms) ===
<current terminal content>
=== END TERMINAL OUTPUT ===
```

## Best Practices

### 1. Always Clean Up

```typescript
afterEach(() => {
  terminal.cleanup();
});
```

Orphaned tmux sessions waste resources. Use `tmux list-sessions` to check for leaks.

### 2. Use Specific Patterns

```typescript
// ✅ Good - specific
await terminal.waitForMatch(/Select an option \(1-3\):/);

// ❌ Bad - too generic, might match early
await terminal.waitForMatch(/Select/);
```

### 3. Add Delays After Input (If Needed)

The helper includes a 50ms delay after `writeLine`, but complex apps might need more:

```typescript
await terminal.writeLine('complex-command');
await new Promise(resolve => setTimeout(resolve, 200));
await terminal.waitForMatch(/Done/);
```

### 4. Test Terminal Dimensions

Some CLI apps behave differently based on terminal size:

```typescript
it('should handle narrow terminals', async () => {
  const terminal = new TmuxTerminalTest('node', ['cli.js'], {
    cols: 40, // Narrow terminal
    rows: 20
  });
  
  // Test responsive behavior
  await terminal.waitForMatch(/Narrow mode detected/);
  terminal.cleanup();
});
```

### 5. Use Raw Output for ANSI Testing

```typescript
it('should display colored output', async () => {
  await terminal.waitForMatch(/Success/);
  
  const raw = terminal.getRawOutput();
  
  // Check for green color code (32m)
  expect(raw).toMatch(/\x1b\[32m.*Success.*\x1b\[0m/);
});
```

### 6. Debug Flaky Tests with attach()

```typescript
it('flaky test', async () => {
  await terminal.waitForMatch(/Step 1/);
  
  // Uncomment to see what's happening:
  // terminal.attach();
  
  terminal.sendKey('enter');
  await terminal.waitForMatch(/Step 2/);
});
```

## Troubleshooting

### Test Times Out

1. Check if tmux is installed: `which tmux`
2. Verify the pattern is correct: look at the error output
3. Increase timeout: `await terminal.waitForMatch(/pattern/, 10000)`
4. Use `terminal.attach()` to debug interactively

### Pattern Never Matches

1. Pattern might be split across lines
2. ANSI codes might interfere - use `getOutput()` to see clean text
3. Output might scroll off screen - increase `rows` option

### Special Characters Don't Work

Some keys require different syntax:
```typescript
// ✅ Correct
terminal.sendKey('ctrl+c');

// ❌ Wrong
terminal.sendKey('C-c');
```

### Session Cleanup Fails

If tests crash and leave sessions, clean them manually:
```bash
# List all test sessions
tmux list-sessions | grep '^test-'

# Kill all test sessions
tmux list-sessions | grep '^test-' | cut -d: -f1 | xargs -n1 tmux kill-session -t
```

## Integration with Jest/Vitest

### Jest Example

```typescript
import { TmuxTerminalTest } from './terminal_test_helper';

describe('CLI E2E Tests', () => {
  let terminal: TmuxTerminalTest;

  beforeEach(() => {
    terminal = new TmuxTerminalTest('npm', ['run', 'cli']);
  });

  afterEach(() => {
    terminal.cleanup();
  });

  it('should work', async () => {
    await terminal.waitForMatch(/Ready/);
    expect(terminal.getOutput()).toContain('Ready');
  });
});
```

### Test Isolation

Each test gets a unique session name:
```typescript
test-1707052547123-a8f4k2
test-1707052548456-b9g5m3
```

This ensures tests can run in parallel without interference.

## Reference Implementation

The complete implementation is available at:
`packages/cli/test/e2e/terminal_test_helper.ts`

Key features:
- Uses Node.js `child_process` (not Bun-specific)
- Compatible with Jest and other test runners
- Proper shell escaping for security
- Playwright-inspired API for familiarity

## Related Resources

- [tmux man page](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Jest documentation](https://jestjs.io/)
- [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- GitLab LS Project: See real usage in `packages/cli/test/e2e/` directory
