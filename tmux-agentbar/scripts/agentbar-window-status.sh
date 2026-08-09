#!/usr/bin/env bash
# agentbar-window-status.sh <window-index>
#
# Prints the Claude Code agent status icon for the given tmux window index.
# Designed for use inside tmux's window-status-format via `#(... #I)`.
#
# Output is always 2 columns: either `ICON ` (icon + space) or 2 spaces —
# so the tab width never changes, which prevents status-bar reflow flicker.
#
# The status shown is an aggregate over the window's live panes, so a window
# hosting an agent team reads as one thing: `thinking` while any teammate is
# still working, `waiting` the moment any of them needs you, `done` only once
# the last one lands. See agentbar-lib.sh for the precedence rules.
#
# Vendored from https://github.com/dcryan/tmux-agentbar (MIT), with local
# pane-keying changes — see agentbar-lib.sh.

. "$(dirname "${BASH_SOURCE[0]}")/agentbar-lib.sh"

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

# True if any descendant process of the given pane pids has argv matching a
# known agent. tmux's #{pane_current_command} is unreliable (Claude Code
# rewrites its process title to its version string), so we walk the tree.
has_agent_in_window() {
    # Pids arrive space-separated — BSD awk (macOS) errors on `-v roots=$pids`
    # when $pids contains a newline, which happens in any window with >1 pane.
    # Upstream bug; fixed here.
    local pids="$1"
    [ -z "${pids// /}" ] && return 1

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

# One list-panes call for both the pids (agent detection) and the pane ids
# (state aggregation) — this runs once per window per second, so the round
# trip is worth collapsing.
panes=$(tmux list-panes -t "${session_name}:${win_idx}" \
    -F '#{pane_id} #{pane_pid}' 2>/dev/null)
[ -z "$panes" ] && blank

pane_ids=$(printf '%s\n' "$panes" | cut -d' ' -f1 | tr '\n' ' ')
pane_pids=$(printf '%s\n' "$panes" | cut -d' ' -f2 | tr '\n' ' ')

has_agent_in_window "$pane_pids" || blank

state_dir=$(agentbar_state_dir "$session_id" "$win_idx")
# Word splitting is the point here: pane ids are `%N` tokens, never globs.
# shellcheck disable=SC2086
status=$(agentbar_window_status "$state_dir" $pane_ids)

printf '%s  %s ' "$ROBOT" "$(icon_for "$status")"
