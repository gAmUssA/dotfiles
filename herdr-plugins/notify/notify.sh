#!/usr/bin/env bash
#
# herdr plugin event hook — pane.agent_status_changed.
#
# Raises ONE desktop banner when a herdr agent reaches a state worth
# interrupting you for, and routes a click back to that exact pane.
#
# Runs server-side, so unlike herdr's built-in `[ui.toast]` it still fires when
# no client is attached — the normal state for an always-on herdr host, and the
# case where a notification matters most. That gap is why this exists:
# `herdr notification show` answers {"shown":false,"reason":"no_foreground_client"}
# when detached.
#
# Pairs with claude/stop-hook.sh, which suppresses itself inside herdr
# (HERDR_ENV) precisely so this is the only banner. Keep that contract: if you
# disable this plugin, re-check that stop-hook still notifies, or turns finish
# silently.
#
# Environment provided by herdr:
#   HERDR_PLUGIN_EVENT       "pane.agent_status_changed"
#   HERDR_PLUGIN_EVENT_JSON  full payload (agent, status, previous status)
#   HERDR_PANE_ID            e.g. w6:pC   — what click-to-focus needs
#   HERDR_WORKSPACE_ID       e.g. w6
#   HERDR_TAB_ID             e.g. w6:t1
#   HERDR_PLUGIN_STATE_DIR   writable, plugin-private
#
# Debug: HERDR_NOTIFY_DEBUG=1 logs decisions to $HERDR_PLUGIN_STATE_DIR/notify.log
# (or /tmp when running it by hand outside herdr).

set -u

ALERTER=/opt/homebrew/bin/alerter
ICONS="$HOME/projects/dotfiles/iterm2-icons"
APP_ICON="$ICONS/herdr.png"          # herdr's own logo, from herdr.dev
HERDR_BIN="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"

payload="${HERDR_PLUGIN_EVENT_JSON:-}"


log_dir="${HERDR_PLUGIN_STATE_DIR:-/tmp}"
log() {
  [[ -n "${HERDR_NOTIFY_DEBUG:-}" ]] || return 0
  printf '[%s] %s\n' "$(date '+%FT%T')" "$*" >> "$log_dir/notify.log"
}

# --- Which states are worth interrupting for? -------------------------------
#
# `done` and `blocked` only. `working`, `idle`, and `unknown` are transitions
# you neither asked for nor can act on — notifying on those turns a useful
# signal into noise you learn to ignore. blocked means the agent is waiting on
# YOU, which is the most actionable state of all.
# Payload shape (verified against herdr 0.8.2 — everything is under .data, and
# it carries NO name or cwd, so those are fetched separately below):
#   {"event":"pane_agent_status_changed",
#    "data":{"type":...,"pane_id":"w9:p1","workspace_id":"w9",
#            "agent_status":"done","agent":"claude"}}
status=$(printf '%s' "$payload" | jq -r '.data.agent_status // empty' 2>/dev/null)
agent=$(printf '%s'  "$payload" | jq -r '.data.agent // empty' 2>/dev/null)
# Prefer the pane from the payload; HERDR_PANE_ID is not guaranteed for events.
pane=$(printf '%s'   "$payload" | jq -r '.data.pane_id // empty' 2>/dev/null)
[[ -z "$pane" ]] && pane="${HERDR_PANE_ID:-}"

case "$status" in
  done|blocked) ;;
  *) log "skip status=$status pane=$pane"; exit 0 ;;
esac

# Only now (a state we WILL notify for) pay for a lookup, to turn "claude" into
# the renamed label ("architect", "reviewer") and to get the project directory.
detail=$("$HERDR_BIN" agent get "$pane" 2>/dev/null)
name=$(printf '%s' "$detail" | jq -r '.result.agent.name // empty' 2>/dev/null)
cwd=$(printf '%s'  "$detail" | jq -r '.result.agent.cwd // empty' 2>/dev/null)

label="${name:-${agent:-agent}}"
project=$(basename "${cwd:-}" 2>/dev/null)
[[ -z "$project" || "$project" == "." ]] && project="${HERDR_WORKSPACE_ID:-herdr}"

if [[ "$status" == "blocked" ]]; then
  message="needs your input"
  sound="Funk"
else
  message="turn complete"
  sound="Glass"
fi

log "notify status=$status agent=$label pane=$pane project=$project"

# --group keyed per pane so back-to-back turns in ONE pane replace each other,
# while different panes still get their own banner — with several agents running
# a single shared group would silently swallow all but the newest.
(
  result=$("$ALERTER" \
    --title "herdr · $label" \
    --subtitle "$project" \
    --message "$message" \
    --sound "$sound" \
    --app-icon "$APP_ICON" \
    --ignore-dnd \
    --group "herdr-${pane:-all}" \
    --timeout 30 \
    2>/dev/null)

  if [[ "$result" == "@CONTENTCLICKED" && -n "$pane" ]]; then
    # Focus the pane inside herdr first, then raise a terminal so the focused
    # pane is actually on screen. herdr knows its own layout; we just ask.
    "$HERDR_BIN" agent focus "$pane" >/dev/null 2>&1 \
      || "$HERDR_BIN" pane zoom "$pane" --off >/dev/null 2>&1 || true
    open -a Ghostty 2>/dev/null || open -a iTerm 2>/dev/null || true
    log "clicked -> focused $pane"
  fi
) &

exit 0
