#!/usr/bin/env bash
#
# Paste the macOS clipboard image into the current pane.
# - If the pane looks like a Claude Code prompt, sends `/image <path>` + Enter
# - Otherwise, pastes just the path so you can use it elsewhere
#
# Requires: pngpaste (brew install pngpaste)
#
# NOT currently bound — Claude Code handles clipboard paste natively now.
# To activate, add to ~/.tmux.conf:
#   bind V run-shell "~/projects/dotfiles/tmux-paste-image.sh"
# Then reload tmux config and use `prefix + V`.

set -euo pipefail

IMG_DIR="${TMPDIR:-/tmp}/tmux-paste-images"
mkdir -p "$IMG_DIR"
FILENAME="clipboard-$(date +%Y%m%d-%H%M%S).png"
FILEPATH="$IMG_DIR/$FILENAME"

if ! command -v pngpaste >/dev/null 2>&1; then
  tmux display-message "pngpaste not installed (brew install pngpaste)"
  exit 1
fi

if ! pngpaste "$FILEPATH" 2>/dev/null; then
  tmux display-message "No image in clipboard"
  exit 1
fi

# Peek at the last few lines of the active pane to detect a Claude Code prompt
PANE_CONTENT=$(tmux capture-pane -p -l 5)
if echo "$PANE_CONTENT" | grep -qE '›|> '; then
  tmux send-keys "/image $FILEPATH" Enter
else
  tmux send-keys "$FILEPATH"
fi
