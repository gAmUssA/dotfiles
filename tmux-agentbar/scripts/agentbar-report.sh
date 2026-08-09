#!/usr/bin/env bash
# agentbar-report.sh <status>
#
# Reports an agent status for the caller's tmux PANE: writes the status to a
# per-pane state file (read by agentbar-window-status.sh for the per-tab icon)
# and, when the WINDOW as a whole becomes attention-worthy, emits a terminal
# BEL so tmux flips the tab to its window-status-bell-style (reverse video by
# default) until the user focuses it. Designed to be invoked from Claude Code
# hooks (UserPromptSubmit, Stop, Notification, SessionStart). Silently no-ops
# when not inside tmux.
#
# Status must be one of: idle | thinking | waiting | done
#
# Bell fires when the window's AGGREGATE status transitions into waiting or
# done — not on every report. Two reasons:
#   - Agent teams put N teammates in one window. Ringing per teammate meant
#     N bells per team turn; now the window rings once, when the last
#     teammate lands (see the precedence note in agentbar-lib.sh).
#   - Repeated identical reports (two `done`s in a row) no longer double-ring.
#
# Vendored from https://github.com/dcryan/tmux-agentbar (MIT), with local
# pane-keying changes — see agentbar-lib.sh.

status="${1:-}"
case "$status" in
    idle|thinking|waiting|done) ;;
    *) exit 0 ;;
esac

# Must be inside tmux (hook fired from a tmux-hosted Claude pane).
[ -z "${TMUX_PANE:-}" ] && exit 0
command -v tmux >/dev/null 2>&1 || exit 0

. "$(dirname "${BASH_SOURCE[0]}")/agentbar-lib.sh"

# One round-trip for all three identifiers. $TMUX_PANE is the pane this hook's
# claude process lives in — for a teammate that is its own spawned pane, which
# is exactly the granularity we want to key on.
read -r session_id win_idx pane_id <<<"$(tmux display-message -p -t "$TMUX_PANE" \
    '#{session_id} #{window_index} #{pane_id}' 2>/dev/null)"
[ -z "$session_id" ] || [ -z "$win_idx" ] || [ -z "$pane_id" ] && exit 0

state_dir=$(agentbar_state_dir "$session_id" "$win_idx")

# Upgrade path: the pre-pane-keying layout put a regular FILE at this path.
# mkdir -p would fail against it and every report would silently no-op.
[ -f "$state_dir" ] && rm -f "$state_dir" 2>/dev/null
mkdir -p "$state_dir" 2>/dev/null || exit 0

# Live panes only, so a torn-down teammate's stale state can't affect the
# transition test below.
read -r -a live_panes <<<"$(tmux list-panes -t "${session_id}:${win_idx}" \
    -F '#{pane_id}' 2>/dev/null | tr '\n' ' ')"
agentbar_prune "$state_dir" "${live_panes[@]}"

before=$(agentbar_window_status "$state_dir" "${live_panes[@]}")
printf '%s\n' "$status" > "$state_dir/pane-${pane_id#%}"
after=$(agentbar_window_status "$state_dir" "${live_panes[@]}")

if [ "$before" != "$after" ]; then
    case "$after" in
        waiting|done) printf '\a' >/dev/tty 2>/dev/null || true ;;
    esac
fi
