---
name: tmux-cli-testing
description: Test interactive CLI applications using tmux sessions. Simple shell script helper for testing terminal apps.
---

# Testing Interactive CLI Applications

Test any interactive CLI app using tmux sessions and shell scripts.

## Basic Pattern

```bash
#!/usr/bin/env bash
source scripts/tmux_test_helper.sh
trap cleanup_test EXIT

# Start app
start_test "your-command" "arg1" "arg2"

# Wait for ready state
wait_for "expected pattern" 30

# Interact
send_line "input text"
send_key enter

# Verify
output=$(get_output)
echo "$output" | grep "expected result"

# Cleanup (automatic via trap)
```

## Core Functions

### Session Management
- `start_test COMMAND [ARGS...]` - Start app in tmux session
- `cleanup_test` - Kill session (use with `trap cleanup_test EXIT`)
- `is_session_alive` - Check if session is running
- `attach_session` - Debug interactively (Ctrl+B then D to detach)

### Input
- `send_line TEXT` - Send text + Enter
- `send_text TEXT` - Send text without Enter
- `send_key KEY` - Send special key (enter, escape, tab, up, down, left, right, ctrl-c, ctrl-d, etc.)

### Output
- `get_output` - Get terminal output (ANSI codes stripped)
- `get_raw_output` - Get output with ANSI codes (for color testing)
- `wait_for PATTERN [TIMEOUT]` - Wait for pattern to appear (default 30s timeout)

### Utilities
- `list_test_sessions` - Show active test sessions
- `kill_all_test_sessions` - Clean up orphaned sessions
- `log_info MSG`, `log_success MSG`, `log_error MSG`, `log_warn MSG` - Logging

## Quick Example

```bash
#!/usr/bin/env bash
source scripts/tmux_test_helper.sh
trap cleanup_test EXIT

start_test "duo"
wait_for "Type your message here" 40
send_line "What is 2+2?"
wait_for "Duo is thinking" 5
sleep 5

output=$(get_output)
if echo "$output" | grep -q "4"; then
    log_success "Duo answered correctly"
fi
```

## Debugging

When tests fail:
```bash
attach_session  # See live terminal
get_output | less  # Scroll through output
```

Timeout errors automatically show current terminal output for debugging.

## See Also

- **references/REFERENCE.md** - Add additional insights and findings here
- **scripts/tmux_test_helper.sh** - Helper script implementation
