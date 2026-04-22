#!/usr/bin/env bash
# agentbar-report.sh <status>
#
# Reports an agent status for the caller's tmux window: writes the status to
# a state file (read by agentbar-window-status.sh for the per-tab icon) and, for
# attention-worthy statuses, emits a terminal BEL so tmux flips the tab to
# its window-status-bell-style (reverse video by default) until the user
# focuses it. Designed to be invoked from Claude Code hooks (UserPromptSubmit,
# Stop, Notification, SessionStart). Silently no-ops when not inside tmux.
#
# Status must be one of: idle | thinking | waiting | done
# Bell fires for: waiting, done (agent needs user / agent finished)
#
# Vendored from https://github.com/dcryan/tmux-agentbar (MIT)

status="${1:-}"
case "$status" in
    idle|thinking|waiting|done) ;;
    *) exit 0 ;;
esac

# Must be inside tmux (hook fired from a tmux-hosted Claude pane).
[ -z "${TMUX_PANE:-}" ] && exit 0
command -v tmux >/dev/null 2>&1 || exit 0

session_id=$(tmux display-message -p -t "$TMUX_PANE" '#{session_id}' 2>/dev/null)
win_idx=$(tmux display-message -p -t "$TMUX_PANE" '#{window_index}' 2>/dev/null)
[ -z "$session_id" ] || [ -z "$win_idx" ] && exit 0

state_dir="${TMPDIR:-/tmp}/tmux-agentbar/${session_id}"
mkdir -p "$state_dir" 2>/dev/null
printf '%s\n' "$status" > "$state_dir/win-${win_idx}"

case "$status" in
    waiting|done) printf '\a' >/dev/tty 2>/dev/null || true ;;
esac
