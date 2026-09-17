#!/usr/bin/env bash
# Show "what just happened" via the Hammerspoon HUD (hammerspoon/aerospace_hud.lua).
# Usage: aerospace-hud.sh "Focus left" "Hyper+h"
# Silent no-op if Hammerspoon isn't running, so a binding never breaks over it.
set -u
pgrep -xq Hammerspoon || exit 0
enc() { printf '%s' "$1" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read(),safe=""))'; }
open -g "hammerspoon://aerospace-hud?msg=$(enc "${1:-}")&key=$(enc "${2:-}")"
