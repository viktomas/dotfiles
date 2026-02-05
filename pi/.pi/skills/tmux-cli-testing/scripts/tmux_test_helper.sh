#!/usr/bin/env bash
#
# Tmux Terminal Testing Helper
# A simple, foolproof way to test interactive CLI applications
#
# Usage:
#   source tmux_test_helper.sh
#   start_test "command" "arg1" "arg2"
#   wait_for "pattern"
#   send_line "input text"
#   send_key "enter"
#   output=$(get_output)
#   cleanup_test

set -euo pipefail

# Global variables
TMUX_SESSION=""
TMUX_SESSION_PID=""
TEST_CLEANUP_REGISTERED=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

#
# Start a new tmux test session
#
# Usage: start_test COMMAND [ARGS...]
# Example: start_test "duo"
# Example: start_test "node" "cli.js"
#
start_test() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: start_test COMMAND [ARGS...]"
        return 1
    fi

    local command="$1"
    shift
    local args=("$@")

    # Check if tmux is installed
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed. Install it with: brew install tmux"
        return 1
    fi

    # Check if command exists
    if ! command -v "$command" &> /dev/null; then
        log_error "Command not found: $command"
        return 1
    fi

    # Generate unique session name
    TMUX_SESSION="test-$(date +%s)-$$"
    
    log_info "Creating tmux session: $TMUX_SESSION"

    # Create tmux session with reasonable size
    if ! tmux new-session -d -s "$TMUX_SESSION" -x 120 -y 40; then
        log_error "Failed to create tmux session"
        return 1
    fi

    # Register cleanup trap if not already registered
    if [[ "$TEST_CLEANUP_REGISTERED" == "false" ]]; then
        trap cleanup_test EXIT INT TERM
        TEST_CLEANUP_REGISTERED=true
    fi

    # Build command with args
    local full_command="$command"
    for arg in "${args[@]}"; do
        # Properly escape arguments
        full_command="$full_command '${arg//\'/\'\\\'\'}'"
    done

    log_info "Starting: $full_command"

    # Send the command to tmux
    tmux send-keys -t "$TMUX_SESSION" "$full_command" Enter

    # Give the process a moment to start
    sleep 0.2

    log_success "Test session started"
    return 0
}

#
# Wait for a pattern to appear in the terminal output
#
# Usage: wait_for PATTERN [TIMEOUT_SECONDS]
# Example: wait_for "ready" 10
# Example: wait_for "Type your message"
#
wait_for() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: wait_for PATTERN [TIMEOUT_SECONDS]"
        return 1
    fi

    local pattern="$1"
    local timeout="${2:-30}"  # Default 30 seconds
    local elapsed=0
    local interval=0.1

    log_info "Waiting for pattern: '$pattern' (timeout: ${timeout}s)"

    while (( $(echo "$elapsed < $timeout" | bc -l) )); do
        # Check if session is still alive
        if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
            log_error "Tmux session died unexpectedly"
            return 1
        fi

        # Get current output
        local output
        output=$(get_output 2>/dev/null || echo "")

        # Check if pattern matches
        if echo "$output" | grep -q "$pattern"; then
            log_success "Pattern found after ${elapsed}s"
            return 0
        fi

        sleep "$interval"
        elapsed=$(echo "$elapsed + $interval" | bc -l)
    done

    # Timeout reached
    log_error "Timeout waiting for pattern: '$pattern'"
    log_error "Current terminal output:"
    echo "════════════════════════════════════════" >&2
    get_output >&2
    echo "════════════════════════════════════════" >&2
    return 1
}

#
# Send a line of text (with Enter at the end)
#
# Usage: send_line TEXT
# Example: send_line "hello world"
#
send_line() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: send_line TEXT"
        return 1
    fi

    local text="$1"
    
    # Send literal text (not interpreted by shell)
    tmux send-keys -t "$TMUX_SESSION" -l "$text"
    # Then send Enter
    tmux send-keys -t "$TMUX_SESSION" Enter
    
    # Small delay for the command to be processed
    sleep 0.1
    
    log_info "Sent line: '$text'"
}

#
# Send raw text without Enter
#
# Usage: send_text TEXT
# Example: send_text "hello"
#
send_text() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: send_text TEXT"
        return 1
    fi

    local text="$1"
    
    tmux send-keys -t "$TMUX_SESSION" -l "$text"
    sleep 0.05
    
    log_info "Sent text: '$text'"
}

#
# Send a special key
#
# Usage: send_key KEY
# Available keys:
#   enter, escape, tab, backspace, delete
#   up, down, left, right, home, end
#   ctrl-c, ctrl-d, ctrl-z
#
# Example: send_key enter
# Example: send_key ctrl-c
#
send_key() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: send_key KEY"
        log_error "Available keys: enter, escape, tab, up, down, left, right, ctrl-c, etc."
        return 1
    fi

    local key="$1"
    local tmux_key=""

    # Map common key names to tmux key names
    case "${key,,}" in
        enter|return)
            tmux_key="Enter"
            ;;
        escape|esc)
            tmux_key="Escape"
            ;;
        tab)
            tmux_key="Tab"
            ;;
        backspace|bspace)
            tmux_key="BSpace"
            ;;
        delete|del)
            tmux_key="DC"
            ;;
        up|up-arrow)
            tmux_key="Up"
            ;;
        down|down-arrow)
            tmux_key="Down"
            ;;
        left|left-arrow)
            tmux_key="Left"
            ;;
        right|right-arrow)
            tmux_key="Right"
            ;;
        home)
            tmux_key="Home"
            ;;
        end)
            tmux_key="End"
            ;;
        ctrl-c|^c)
            tmux_key="C-c"
            ;;
        ctrl-d|^d)
            tmux_key="C-d"
            ;;
        ctrl-z|^z)
            tmux_key="C-z"
            ;;
        ctrl-a|^a)
            tmux_key="C-a"
            ;;
        *)
            log_error "Unknown key: $key"
            return 1
            ;;
    esac

    tmux send-keys -t "$TMUX_SESSION" "$tmux_key"
    sleep 0.05
    
    log_info "Sent key: $key"
}

#
# Get current terminal output (ANSI codes stripped)
#
# Usage: output=$(get_output)
#
get_output() {
    if [[ -z "$TMUX_SESSION" ]]; then
        log_error "No active test session"
        return 1
    fi

    # Capture pane content and strip ANSI codes
    tmux capture-pane -t "$TMUX_SESSION" -p -S 0 | \
        sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

#
# Get current terminal output with ANSI codes (for color testing)
#
# Usage: raw_output=$(get_raw_output)
#
get_raw_output() {
    if [[ -z "$TMUX_SESSION" ]]; then
        log_error "No active test session"
        return 1
    fi

    tmux capture-pane -t "$TMUX_SESSION" -p -e -S 0
}

#
# Check if the session is still alive
#
# Usage: if is_session_alive; then ... fi
#
is_session_alive() {
    if [[ -z "$TMUX_SESSION" ]]; then
        return 1
    fi

    tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

#
# Attach to the session for interactive debugging
# Press Ctrl+B then D to detach
#
# Usage: attach_session
#
attach_session() {
    if [[ -z "$TMUX_SESSION" ]]; then
        log_error "No active test session"
        return 1
    fi

    log_info "Attaching to session: $TMUX_SESSION"
    log_info "Press Ctrl+B then D to detach"
    
    tmux attach -t "$TMUX_SESSION"
}

#
# Clean up the test session
#
# Usage: cleanup_test
#
cleanup_test() {
    if [[ -n "$TMUX_SESSION" ]]; then
        log_info "Cleaning up session: $TMUX_SESSION"
        
        if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
            tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
            log_success "Session cleaned up"
        else
            log_info "Session already closed"
        fi
        
        TMUX_SESSION=""
    fi
}

#
# List all test sessions (for debugging orphaned sessions)
#
# Usage: list_test_sessions
#
list_test_sessions() {
    log_info "Active test sessions:"
    tmux list-sessions 2>/dev/null | grep "^test-" || log_info "No test sessions found"
}

#
# Kill all test sessions (cleanup orphaned sessions)
#
# Usage: kill_all_test_sessions
#
kill_all_test_sessions() {
    log_warn "Killing all test sessions..."
    
    local count=0
    while IFS= read -r session; do
        local session_name
        session_name=$(echo "$session" | cut -d: -f1)
        log_info "Killing: $session_name"
        tmux kill-session -t "$session_name" 2>/dev/null || true
        ((count++))
    done < <(tmux list-sessions 2>/dev/null | grep "^test-" || true)
    
    if [[ $count -gt 0 ]]; then
        log_success "Killed $count session(s)"
    else
        log_info "No test sessions to kill"
    fi
}

# Export functions
export -f start_test
export -f wait_for
export -f send_line
export -f send_text
export -f send_key
export -f get_output
export -f get_raw_output
export -f is_session_alive
export -f attach_session
export -f cleanup_test
export -f list_test_sessions
export -f kill_all_test_sessions
export -f log_info
export -f log_success
export -f log_error
export -f log_warn

log_success "Tmux test helper loaded"
