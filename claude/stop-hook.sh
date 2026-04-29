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
#      - click routes to the specific iTerm session via AppleScript when
#        $ITERM_SESSION_ID is set, otherwise plain `open -a iTerm`
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

# Capture the iTerm session id NOW, before backgrounding alerter — the env
# var $ITERM_SESSION_ID is set by iTerm2's shell integration on the parent
# shell that launched Claude, and inherited through claude → stop-hook.
# Format: w<window>t<tab>p<pane>:<UUID>, e.g. w0t2p0:F753B77A-...
ITERM_SESSION="${ITERM_SESSION_ID:-}"

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
    printf '  cwd=%s\n  name=%s\n  branch=%s\n  iterm=%s\n' \
      "$cwd" "$name" "${branch:-<none>}" "${ITERM_SESSION:-<none>}"
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
    if [[ -n "$ITERM_SESSION" ]]; then
      # Walk windows → tabs → sessions, find the matching session id, focus
      # it. The iterate-and-match is what gets you to the SPECIFIC tab when
      # iTerm has many open. Falls through to plain activate if no match.
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
      # No iTerm session id (running in Ghostty, plain Terminal, etc.)
      open -a iTerm
    fi
  fi
) &

exit 0
