#!/usr/bin/env bash
# agentbar-lib.sh — shared state model for agentbar-report.sh and
# agentbar-window-status.sh. Sourced, never executed.
#
# LOCAL ADDITION (not upstream). Upstream tmux-agentbar keys agent state by
# tmux WINDOW, which assumes one agent per window. Claude Code's agent teams
# (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) break that assumption: when the
# lead is already inside tmux, teammates are spawned as extra PANES in the
# current window, so N agents share one window. Under the window-keyed model
# they all wrote the same state file (last writer wins, icon became noise)
# and each fired its own BEL (one "done" ring per teammate).
#
# So: state is keyed by PANE, and the window's icon is an aggregate over the
# live panes in it.
#
#   ${TMPDIR}/tmux-agentbar/<session_id>/win-<idx>/pane-<n>
#
# Aggregation precedence — waiting > thinking > done > idle:
#   waiting   any pane needs you. Most urgent, so it outranks thinking.
#   thinking  someone is still working; the window is not finished.
#   done      every pane that has reported is finished. Because thinking
#             outranks done, a window only reads `done` once the LAST
#             teammate lands — which is exactly when a team run is over.
#   idle      nothing reported (or everything decayed).

# Path to a window's state directory. <session_id> <window_index>
agentbar_state_dir() {
    printf '%s/tmux-agentbar/%s/win-%s' "${TMPDIR:-/tmp}" "$1" "$2"
}

# Status of a single pane, or `none` if it never reported. <state_dir> <pane_id>
#
# Pane ids are tmux's `%N`; the `%` is stripped for the filename so the path
# stays glob- and shell-safe.
_agentbar_pane_status() {
    local f="$1/pane-${2#%}" s age
    [ -f "$f" ] || { printf 'none'; return; }
    s=$(cat "$f" 2>/dev/null)
    case "$s" in
        idle|thinking|waiting|done) ;;
        *) printf 'none'; return ;;
    esac

    # Decay stale `waiting` → idle. Claude Code doesn't fire a hook when a
    # notification is dismissed, so `waiting` can stick long after the user
    # responded. `thinking` must NOT decay (long tasks legitimately run for
    # minutes without firing another hook). `done`/`idle` are terminal.
    if [ "$s" = "waiting" ]; then
        age=$(( $(date +%s) - $(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0) ))
        [ "$age" -gt 30 ] && s="idle"
    fi
    printf '%s' "$s"
}

# Aggregate status for a window. <state_dir> <pane_id>...
#
# Only the pane ids passed in are consulted, so a dead teammate's leftover
# `thinking` can never pin the window — the caller passes live panes only.
agentbar_window_status() {
    local state_dir="$1"; shift
    local p s waiting=0 thinking=0 done_=0
    for p in "$@"; do
        s=$(_agentbar_pane_status "$state_dir" "$p")
        case "$s" in
            waiting)  waiting=1 ;;
            thinking) thinking=1 ;;
            done)     done_=1 ;;
        esac
    done
    if   [ "$waiting"  -eq 1 ]; then printf 'waiting'
    elif [ "$thinking" -eq 1 ]; then printf 'thinking'
    elif [ "$done_"    -eq 1 ]; then printf 'done'
    else                             printf 'idle'
    fi
}

# Delete state for panes that no longer exist. <state_dir> <live_pane_id>...
#
# Teammate panes are torn down at the end of a team run; without this their
# files accumulate in TMPDIR until reboot. Cheap: one readdir over a handful
# of entries.
agentbar_prune() {
    local state_dir="$1"; shift
    [ -d "$state_dir" ] || return 0
    local live=" $* " f base
    for f in "$state_dir"/pane-*; do
        [ -e "$f" ] || continue           # no matches — glob stayed literal
        base=${f##*/pane-}
        case "$live" in
            *" %$base "*) ;;              # still alive, keep
            *) rm -f "$f" 2>/dev/null ;;
        esac
    done
}
