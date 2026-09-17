#!/usr/bin/env bash
# Open the AeroSpace cheat sheet in Marked 3 (Hyper + /).
# Marked renders the markdown and live-reloads when the file changes, so edits
# to aerospace-help.md show up without reopening. Floated by bundle id in
# aerospace.toml rather than tiled over the workspace you called it from.
set -u
HELP="$HOME/projects/dotfiles/aerospace/aerospace-help.md"
if [[ -d "/Applications/Marked 3.app" ]]; then
  open -a "Marked 3" "$HELP"
else
  open "$HELP"   # whatever handles .md
fi
