#!/usr/bin/env bash
# Open the AeroSpace cheat sheet in Marked (AERO mode: `/`).
#
# Marked renders the markdown and live-reloads on save, so edits show up without
# reopening. Specifically the Setapp build (bundle id
# com.brettterpstra.marked-setapp) — the separate /Applications/Marked 3.app on
# this machine fails to launch (-10673) and is deliberately not used.
set -u
HELP="$HOME/projects/dotfiles/aerospace/aerospace-help.md"
MARKED="/Applications/Setapp/Marked.app"

if [[ -d "$MARKED" ]]; then
  open -a "$MARKED" "$HELP" && exit 0
fi
open "$HELP"   # whatever handles .md
