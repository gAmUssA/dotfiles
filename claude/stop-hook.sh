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
#        (2) AppleScript focuses the iTerm window/tab/pane via
#            $ITERM_SESSION_ID, or plain `open -a iTerm` as fallback
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
APP_ICON="$HOME/projects/dotfiles/iterm2-icons/iTerm2-nord-chevron.png"
CONTENT_IMAGE="$HOME/projects/dotfiles/iterm2-icons/claude.png"

# Capture both env vars NOW, before backgrounding alerter:
#
# $ITERM_SESSION_ID — set by iTerm2's shell integration. Identifies the iTerm
#   pane where the parent shell lives. Format: w<n>t<n>p<n>:<UUID>.
# $TMUX_PANE — set by tmux for processes inside a pane. Identifies the tmux
#   pane where Claude is running. Format: %<n>, e.g. %5.
#
# Both are inherited through the shell → claude → stop-hook chain. Either
# can be empty (Ghostty has no ITERM_SESSION_ID; running outside tmux has no
# TMUX_PANE) and we fall back accordingly.
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

    # Step 2 — focus the right iTerm window/tab/pane. Walk windows → tabs →
    # sessions, match against the captured ITERM_SESSION_ID, select that one.
    # Falls back to plain activate if no match (or no id at all — Ghostty etc.)
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
    else
      open -a iTerm
    fi
  fi
) &

exit 0
