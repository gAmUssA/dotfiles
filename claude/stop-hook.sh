#!/usr/bin/env bash
#
# Claude Code Stop hook.
# Fires when Claude finishes a response turn.
#
# Signals:
#   Desktop notification via alerter → macOS Notification Center banner
#      - title "Claude Code", subtitle is "<project>" or "<project> · <branch>"
#      - iTerm2-nord-chevron PNG as --app-icon (left)
#      - claude.png as --content-image (right)
#      - --ignore-dnd so Focus/DND doesn't swallow it
#      - --group claude-code so back-to-back turns replace the previous banner
#      - click routes to the specific tmux pane in two steps:
#        (1) tmux select-window/select-pane on $TMUX_PANE so the tmux
#            server's idea of "active" matches where Claude is
#        (2) focus the HOST terminal — AppleScript to the exact iTerm
#            window/tab/pane via $ITERM_SESSION_ID
#
# No banner at all inside herdr — herdr-plugins/notify raises its own there,
# for every agent rather than only Claude. iTerm is the only terminal this
# routes to; see the host block below.
#
# Terminal BEL is emitted by tmux-agentbar's `done` report (runs as a sibling
# hook in settings.json), so this script deliberately does NOT write \a — that
# would double-ring.
#
# Note: `--sender com.googlecode.iterm2` was tried and silently hangs on
# macOS 26 (bundle identity validation). Dropped. We use --app-icon instead.
#
# The hook receives Claude Code's JSON payload on stdin with fields:
#   .cwd                 absolute working directory for the session
#   .session_id          UUID
#   .transcript_path     path to session JSONL
#   .hook_event_name     "Stop"
#
# Debug: CLAUDE_STOP_HOOK_DEBUG=1 writes diagnostic output to
#        /tmp/claude-stop-hook.log

set -u

ALERTER=/opt/homebrew/bin/alerter
ICONS="$HOME/projects/dotfiles/iterm2-icons"
CONTENT_IMAGE="$ICONS/claude.png"

# --- Who owns the desktop banner? -------------------------------------------
#
# Exactly one layer may raise a banner per turn, or you get duplicates.
#
# Inside herdr, herdr owns it: it already tracks agent state for the sidebar
# and raises its own notification (`[ui.toast] delivery` in herdr/config.toml),
# and unlike this hook it is agent-agnostic — it covers codex and grok too, not
# just Claude. So bail out here rather than double-ringing. herdr sets
# HERDR_ENV=1 in every pane it owns.
#
# Everywhere else (bare terminal, or tmux) this hook owns the banner.
if [[ -n "${HERDR_ENV:-}" ]]; then
  # ...but ONLY if the herdr-side notifier is actually live. Do not treat
  # herdr's built-in [ui.toast] as the fallback: it requires an attached,
  # foreground client — `herdr notification show` answers
  # {"shown":false,"reason":"no_foreground_client"} when detached — so on an
  # always-on host, blanket suppression here means a finished turn announces
  # itself to nobody. That is worse than a duplicate banner.
  #
  # herdr-plugins/notify runs server-side and has no such gate, so it is the
  # one thing that makes suppression safe. If it is unlinked or disabled, fall
  # through and notify from here.
  _herdr="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"
  if [[ -x "$_herdr" ]] && "$_herdr" plugin list --plugin gamussa.notify --json 2>/dev/null \
       | grep -q '"enabled": *true'; then
    # Logged so CLAUDE_STOP_HOOK_DEBUG can tell "suppressed here" apart from
    # "hook never fired" — otherwise both look identical (an empty log).
    if [[ -n "${CLAUDE_STOP_HOOK_DEBUG:-}" ]]; then
      printf '[%s] stop-hook suppressed (HERDR_ENV=%s; gamussa.notify plugin owns the banner)\n' \
        "$(date '+%FT%T')" "$HERDR_ENV" >> /tmp/claude-stop-hook.log
    fi
    exit 0
  fi
  if [[ -n "${CLAUDE_STOP_HOOK_DEBUG:-}" ]]; then
    printf '[%s] in herdr but gamussa.notify inactive — notifying from the hook\n' \
      "$(date '+%FT%T')" >> /tmp/claude-stop-hook.log
  fi
fi

# --- Host terminal: iTerm only ----------------------------------------------
#
# Deliberately iTerm-only. Everything that raises a window here runs in iTerm —
# Claude in tmux, and herdr in its own iTerm window — and iTerm is the only
# terminal that can be driven to an exact window/tab/session, so a click lands
# on the right split instead of merely raising an app. Ghostty support was
# dropped rather than left as a half-working branch nothing exercises.
#
# $ITERM_SESSION_ID is set by iTerm's shell integration and survives into tmux,
# so it identifies the hosting session in both cases. If it is absent we are
# not in iTerm: still notify (the banner is the point), just without routing.
if [[ -n "${ITERM_SESSION_ID:-}" ]]; then
  APP_ICON="$ICONS/iTerm2-nord-chevron.png"; FOCUS_APP="iTerm"
else
  APP_ICON="$CONTENT_IMAGE";                 FOCUS_APP=""
fi

# Capture both env vars NOW, before backgrounding alerter:
#
# $ITERM_SESSION_ID — set by iTerm2's shell integration. Identifies the iTerm
#   pane where the parent shell lives. Format: w<n>t<n>p<n>:<UUID>.
# $TMUX_PANE — set by tmux for processes inside a pane. Identifies the tmux
#   pane where Claude is running. Format: %<n>, e.g. %5.
#
# Both are inherited through the shell → claude → stop-hook chain. Either
# can be empty (not in iTerm; running outside tmux has no TMUX_PANE) and we
# fall back accordingly.
ITERM_SESSION="${ITERM_SESSION_ID:-}"
TMUX_PANE_CAPTURED="${TMUX_PANE:-}"

# Read hook JSON from stdin (empty-ok; we only need .cwd)
input=$(cat)

# Build notification subtitle from cwd + git branch
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
name=$(basename "${cwd:-session}")
branch=$(git -C "${cwd:-.}" symbolic-ref --short HEAD 2>/dev/null || true)
subtitle="${name}${branch:+ · $branch}"

if [[ -n "${CLAUDE_STOP_HOOK_DEBUG:-}" ]]; then
  {
    printf '[%s] stop-hook fired\n' "$(date '+%FT%T')"
    printf '  cwd=%s\n  name=%s\n  branch=%s\n' "$cwd" "$name" "${branch:-<none>}"
    printf '  iterm=%s\n  tmux_pane=%s\n' \
      "${ITERM_SESSION:-<none>}" "${TMUX_PANE_CAPTURED:-<none>}"
  } >> /tmp/claude-stop-hook.log
fi

# Fire the notification. Background the subshell so the hook returns fast.
# If the user clicks the banner, alerter writes @CONTENTCLICKED to stdout;
# we then focus the specific iTerm session. Other outputs (@TIMEOUT, @CLOSED)
# do nothing.
(
  result=$("$ALERTER" \
    --title "Claude Code" \
    --subtitle "$subtitle" \
    --message "turn complete" \
    --sound Glass \
    --app-icon "$APP_ICON" \
    --content-image "$CONTENT_IMAGE" \
    --ignore-dnd \
    --group claude-code \
    --timeout 30 \
    2>/dev/null)

  if [[ "$result" == "@CONTENTCLICKED" ]]; then
    # Step 1 — route inside tmux. Switch the attached client to the right
    # session, then select the right window and pane. iTerm has no idea
    # which tmux pane Claude lives in; only the tmux server does.
    if [[ -n "$TMUX_PANE_CAPTURED" ]]; then
      tmux_session=$(tmux display-message -p -t "$TMUX_PANE_CAPTURED" '#{session_name}' 2>/dev/null)
      if [[ -n "$tmux_session" ]]; then
        tmux switch-client -t "$tmux_session" 2>/dev/null
        tmux select-window -t "$TMUX_PANE_CAPTURED" 2>/dev/null
        tmux select-pane   -t "$TMUX_PANE_CAPTURED" 2>/dev/null
      fi
    fi

    # Step 2 — focus the host terminal. Only iTerm can be driven down to the
    # exact tab/pane (AppleScript + $ITERM_SESSION_ID). tmux step 1 above has
    # already moved the right pane under the cursor inside that session.
    if [[ -n "$ITERM_SESSION" ]]; then
      osascript <<APPLESCRIPT 2>/dev/null
tell application "iTerm"
  activate
  repeat with theWindow in windows
    repeat with theTab in tabs of theWindow
      repeat with theSession in sessions of theTab
        if id of theSession is "$ITERM_SESSION" then
          select theWindow
          select theTab
          select theSession
          return
        end if
      end repeat
    end repeat
  end repeat
end tell
APPLESCRIPT
    elif [[ -n "$FOCUS_APP" ]]; then
      open -a "$FOCUS_APP"
    fi
  fi
) &

exit 0
