#!/usr/bin/env bash
# Agents blocked on you (red) or finished while you looked elsewhere (green),
# across every host LCARS Ops watches. Hidden when Ops is down or all is quiet.
PATH=/opt/homebrew/bin:$PATH
source "$CONFIG_DIR/colors.sh"
token=$(cat "${OPS_STATE_DIR:-$HOME/.local/state/ops}/token" 2>/dev/null)
json=$(curl -fsS -m 1 -H "Authorization: Bearer $token" http://127.0.0.1:7677/sessions 2>/dev/null) ||
  { sketchybar --set "$NAME" drawing=off; exit 0; }

read -r blocked finished <<< "$(jq -r '[.sessions[].state] | "\(map(select(. == "blocked")) | length) \(map(select(. == "done")) | length)"' <<< "$json")"
if [ "${blocked:-0}" -gt 0 ]; then
  label="$blocked waiting"; [ "$finished" -gt 0 ] && label="$label · $finished done"; color=$RED
elif [ "${finished:-0}" -gt 0 ]; then
  label="$finished done"; color=$GREEN
else
  sketchybar --set "$NAME" drawing=off; exit 0
fi
sketchybar --set "$NAME" drawing=on icon="󰚩" icon.color=$color label="$label"
