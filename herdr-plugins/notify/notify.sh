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

# --- Raise the terminal window that actually hosts this herdr session --------
#
# `herdr agent focus` moves focus INSIDE herdr, but the herdr client is just a
# process in some terminal window — if that window isn't frontmost you see
# nothing. So find the client and raise its real window.
#
# The first version here ran `open -a Ghostty || open -a iTerm`, which is wrong
# twice over: it assumed Ghostty, and `open -a` LAUNCHES a missing app and
# reports success, so the `||` fallback could never run. It reliably raised the
# wrong terminal.
focus_client() {
  # Which herdr session fired this? Derive from the socket the server gave us:
  #   default -> ~/.config/herdr/herdr.sock
  #   named   -> ~/.config/herdr/sessions/<name>/herdr.sock
  local sock="${HERDR_SOCKET_PATH:-}" sess="" tty_dev="" app=""
  case "$sock" in
    */sessions/*) sess="${sock#*/sessions/}"; sess="${sess%%/*}" ;;
  esac

  # The client for that session. Match precisely on argv[0] being the herdr
  # binary, NOT a substring of the whole line: this plugin's own path contains
  # "herdr" (herdr-plugins/notify/notify.sh), as does `alerter --title herdr`,
  # and both run with tty "??" — a loose /herdr/ match picked one of those
  # first and concluded "no client attached" while a client was right there.
  #
  # Session matching also has to accept `herdr --session default`, which is a
  # normal way to attach to the DEFAULT session (`herdr session list` shows
  # "default" living at ~/.config/herdr, not under sessions/). Treating any
  # --session as "named" sent default-session clicks down the no-client path.
  [[ -z "$sess" ]] && sess="default"
  tty_dev=$(ps -eo tty=,command= | awk -v s="$sess" '
    $1 == "??" { next }                       # no controlling terminal
    {
      n = split($2, parts, "/")
      if (parts[n] != "herdr") next           # argv[0] must BE herdr
      if ($3 == "server") next                # the daemon, not a client
      if (index($0, "--session " s)) { print $1; exit }
      if (s == "default" && $0 !~ /--session/) { print $1; exit }
    }')
  log "focus_client session='${sess:-default}' tty='${tty_dev:-none}'"

  # No tty means NO CLIENT IS ATTACHED to this session — the normal state for
  # an always-on herdr host. There is no window to raise, so open one and
  # attach. Clicking "agent finished" and getting nothing would be a dead end.
  if [[ -z "$tty_dev" || "$tty_dev" == "??" ]]; then
    local cmd="herdr"
    [[ -n "$sess" ]] && cmd="herdr --session $sess"
    log "no client attached; opening one with: $cmd"
    # iTerm first: it can create a window AND run the command in it. Ghostty is
    # the fallback and needs --command=; `open -na Ghostty --args -e ...` opens
    # a window that does not run the command, which is how a click ended up
    # raising an empty Ghostty.
    if osascript -e "tell application \"iTerm\"
          activate
          set w to (create window with default profile)
          tell current session of w to write text \"$cmd\"
        end tell" >/dev/null 2>&1; then
      log "opened iTerm client for session ${sess}"
    else
      open -na Ghostty --args --command="$cmd" >/dev/null 2>&1 \
        && log "opened Ghostty client for session ${sess}" \
        || log "could not open any client (check Automation permission)"
    fi
    return 0
  fi

  # iTerm can be driven down to the exact window/tab/session by tty, so try it
  # first and only accept it if a session actually matched.
  if osascript <<OSA 2>/dev/null | grep -q '^matched'
tell application "iTerm"
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if (tty of s) is "/dev/$tty_dev" then
          activate
          select w
          select t
          select s
          return "matched"
        end if
      end repeat
    end repeat
  end repeat
  return "nomatch"
end tell
OSA
  then
    log "focused iTerm session on /dev/$tty_dev"
    return 0
  fi

  # Otherwise identify the owning app from the client's ancestry and just raise
  # it — Ghostty has no per-session scripting, so app-level is the best we get.
  local p ppid comm
  p=$(ps -eo pid=,tty= | awk -v t="$tty_dev" '$2==t {print $1; exit}')
  for _ in 1 2 3 4 5 6 7 8; do
    [[ -z "$p" || "$p" == "1" ]] && break
    read -r ppid comm <<<"$(ps -o ppid=,comm= -p "$p" 2>/dev/null)"
    [[ -z "$ppid" ]] && break
    case "$comm" in
      *Ghostty*)  app="Ghostty"; break ;;
      *iTerm*)    app="iTerm";   break ;;
      *WezTerm*)  app="WezTerm"; break ;;
      *kitty*)    app="kitty";   break ;;
      *Alacritty*) app="Alacritty"; break ;;
    esac
    p="$ppid"
  done
  if [[ -n "$app" ]]; then
    open -a "$app" 2>/dev/null || true
    log "raised app=$app for /dev/$tty_dev"
  else
    log "no owning terminal app found for /dev/$tty_dev"
  fi
}

# Standalone check: `notify.sh --focus-test` exercises the routing above
# without waiting for a real notification click.
if [[ "${1:-}" == "--focus-test" ]]; then
  HERDR_NOTIFY_DEBUG=1 log_dir="${HERDR_PLUGIN_STATE_DIR:-/tmp}" focus_client
  exit 0
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
    "$HERDR_BIN" agent focus "$pane" >/dev/null 2>&1 || true
    focus_client
    log "clicked -> focused $pane"
  fi
) &

exit 0
