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
#   HERDR_SOCKET_PATH       originating session's API socket (required)
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

PLUGIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# alerter: explicit override, else PATH, else the two standard Homebrew
# prefixes (Apple Silicon, Intel). Plugin hooks run with the herdr SERVER's
# environment, not your shell's, so PATH alone is not guaranteed to have it.
ALERTER="${HERDR_NOTIFY_ALERTER:-$(command -v alerter 2>/dev/null)}"
for candidate in /opt/homebrew/bin/alerter /usr/local/bin/alerter; do
  [[ -x "$ALERTER" ]] && break
  ALERTER="$candidate"
done

# Icon ships inside the plugin, so it works wherever the plugin is installed.
APP_ICON="${HERDR_NOTIFY_ICON:-$PLUGIN_DIR/icon.png}"
HERDR_BIN="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"
socket_path="${HERDR_SOCKET_PATH:-}"
payload="${HERDR_PLUGIN_EVENT_JSON:-}"


log_dir="${HERDR_PLUGIN_STATE_DIR:-/tmp}"
log() {
  # Enabled by env OR a marker file, because the herdr server does not pass
  # HERDR_NOTIFY_DEBUG into plugin hooks — `touch $HERDR_PLUGIN_STATE_DIR/debug`
  # is the only way to get logs out of a real event.
  [[ -n "${HERDR_NOTIFY_DEBUG:-}" || -f "$log_dir/debug" ]] || return 0
  printf '[%s] %s\n' "$(date '+%FT%T')" "$*" >> "$log_dir/notify.log"
}

log_env() {
  log "env HERDR_SOCKET_PATH='${HERDR_SOCKET_PATH:-UNSET}' HERDR_PANE_ID='${HERDR_PANE_ID:-UNSET}' HERDR_WORKSPACE_ID='${HERDR_WORKSPACE_ID:-UNSET}' HERDR_BIN_PATH='${HERDR_BIN_PATH:-UNSET}'"
}

# Route through the exact originating socket and the captured terminal identity.
# --focus-test now exercises the same workspace/tab/pane + iTerm path as a click:
#   HERDR_PANE_ID=w1:p1 notify.sh --focus-test
route_click() {
  local result
  if [[ -z "$socket_path" || -z "$terminal_id" ]]; then
    log "routing failed: missing originating socket or terminal identity"
    return 1
  fi
  if result=$(python3 "$PLUGIN_DIR/focus.py" --socket "$socket_path" \
      --terminal "$terminal_id" --herdr-bin "$HERDR_BIN" 2>&1); then
    log "clicked -> $result"
  else
    log "$result"
    return 1
  fi
}

if [[ "${1:-}" == "--focus-test" ]]; then
  HERDR_NOTIFY_DEBUG=1
  detail=$("$HERDR_BIN" pane get "${HERDR_PANE_ID:?set HERDR_PANE_ID}" 2>/dev/null)
  terminal_id=$(printf '%s' "$detail" | jq -r '.result.pane.terminal_id // empty')
  route_click
  exit $?
fi

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
detail=$("$HERDR_BIN" agent get "$pane" 2>/dev/null) ||
  detail=$("$HERDR_BIN" pane get "$pane" 2>/dev/null)
terminal_id=$(printf '%s' "$detail" | jq -r '(.result.agent // .result.pane).terminal_id // empty' 2>/dev/null)
name=$(printf '%s' "$detail" | jq -r '.result.agent.name // empty' 2>/dev/null)
cwd=$(printf '%s'  "$detail" | jq -r '(.result.agent // .result.pane).cwd // empty' 2>/dev/null)

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
log_env

# Pane IDs are scoped to a server. Include the socket so w1:p1 in two sessions
# cannot replace each other's banners (and hence their click destinations).
group=$(printf '%s\0%s' "$socket_path" "$pane" | shasum -a 256)
group="herdr-${group%% *}"
(
  result=$("$ALERTER" \
    --title "herdr · $label" \
    --subtitle "$project" \
    --message "$message" \
    --sound "$sound" \
    --app-icon "$APP_ICON" \
    --ignore-dnd \
    --group "$group" \
    --timeout 30 \
    2>/dev/null)

  if [[ "$result" == "@CONTENTCLICKED" && -n "$pane" ]]; then
    route_click
  fi
) &

exit 0
