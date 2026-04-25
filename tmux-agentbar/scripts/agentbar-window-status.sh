#!/usr/bin/env bash
# agentbar-window-status.sh <window-index>
#
# Prints the Claude Code agent status icon for the given tmux window index.
# Designed for use inside tmux's window-status-format via `#(... #I)`.
#
# Output is always 2 columns: either `ICON ` (icon + space) or 2 spaces —
# so the tab width never changes, which prevents status-bar reflow flicker.
#
# Vendored from https://github.com/dcryan/tmux-agentbar (MIT)

# Nerd Font fa-robot (U+EE0D). Emitted on every agent window so the tab
# clearly reads as "agent lives here" regardless of which agent it is —
# pane_current_command alone was unreliable (Claude rewrites to a version
# string, copilot shows as `node`).
ROBOT=$(printf '\xee\xb8\x8d')

_SPINNER=(✢ ✳ ✶ ✻ ✽ ✻ ✶ ✳)

icon_for() {
    # tmux interprets #[fg=...] specs inside shell-output substitutions, so
    # we can color each state inline. We restore fg to #f8f8f2 (Dracula's
    # tab-text color, same for normal and current tabs) after the glyph
    # instead of using #[default] — #[default] would also reset bg, which
    # strips Dracula's tab background and breaks the powerline chevrons on
    # the current tab. Colors below are from the Dracula palette.
    case "$1" in
        waiting)  printf '#[fg=#ff5555]⏸#[fg=#f8f8f2]' ;;                             # red — needs you
        thinking) printf '#[fg=#f1fa8c]%s#[fg=#f8f8f2]' \
                      "${_SPINNER[$(( $(date +%s) % ${#_SPINNER[@]} ))]}" ;;       # yellow — processing
        done)     printf '#[fg=#50fa7b]✓#[fg=#f8f8f2]' ;;                             # green — completed
        idle|*)   printf '#[fg=#6272a4]∘#[fg=#f8f8f2]' ;;                             # gray — recedes
    esac
}

# True if any descendant process of the pane's root pid has argv matching
# a known agent. tmux's #{pane_current_command} is unreliable (Claude Code
# rewrites its process title to its version string), so we walk the tree.
has_agent_in_window() {
    local win_target="$1"
    local pids
    # Collapse newlines to spaces — BSD awk (macOS) errors on `-v roots=$pids`
    # when $pids contains a newline, which happens in any window with >1 pane.
    # Upstream bug; fixed here.
    pids=$(tmux list-panes -t "$win_target" -F '#{pane_pid}' 2>/dev/null | tr '\n' ' ')
    [ -z "$pids" ] && return 1

    ps -ao pid=,ppid=,args= 2>/dev/null | awk -v roots="$pids" '
        BEGIN { n = split(roots, r, /[[:space:]]+/); for (i=1; i<=n; i++) if (r[i] != "") tree[r[i]] = 1 }
        { pid=$1; ppid=$2; $1=""; $2=""; sub(/^  */,"",$0); argv[pid]=$0; parent[pid]=ppid }
        END {
            changed = 1
            while (changed) {
                changed = 0
                for (p in parent) if (!(p in tree) && (parent[p] in tree)) { tree[p] = 1; changed = 1 }
            }
            for (p in tree) if (argv[p] ~ /claude|aider|cursor|copilot|cline/) { exit 0 }
            exit 1
        }'
}

# Emit nothing when no agent is in the window. The icon sits BEFORE the window
# name in window-status-format, so an empty string + the space we add on the
# agent branch leaves a clean `1 dotfiles` for non-agent tabs.
blank() { exit 0; }

win_idx="${1:-}"
[ -z "$win_idx" ] && blank

session_name=$(tmux display-message -p '#{session_name}' 2>/dev/null)
session_id=$(tmux display-message -p '#{session_id}' 2>/dev/null)
[ -z "$session_name" ] || [ -z "$session_id" ] && blank

has_agent_in_window "${session_name}:${win_idx}" || blank

state_file="${TMPDIR:-/tmp}/tmux-agentbar/${session_id}/win-${win_idx}"
status="idle"
[ -f "$state_file" ] && status=$(cat "$state_file")

# Decay stale `waiting` → idle. Claude Code doesn't fire a hook when a
# notification is dismissed, so `waiting` can stick long after the user
# responded. `thinking` must NOT decay (long tasks legitimately run for
# minutes without firing another hook). `done`/`idle` are terminal.
if [ "$status" = "waiting" ] && [ -f "$state_file" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$state_file" 2>/dev/null || stat -c %Y "$state_file" 2>/dev/null || echo 0) ))
    [ "$age" -gt 30 ] && status="idle"
fi

printf '%s  %s ' "$ROBOT" "$(icon_for "$status")"
