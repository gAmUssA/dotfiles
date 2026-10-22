#!/usr/bin/env bash
batt=$(pmset -g batt)
pct=$(printf '%s' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -z "$pct" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }
source "$CONFIG_DIR/colors.sh"

color=$WHITE
if printf '%s' "$batt" | grep -q 'AC Power'; then icon="󰂄"
elif [ "$pct" -ge 80 ]; then icon="󰁹"
elif [ "$pct" -ge 50 ]; then icon="󰁿"
elif [ "$pct" -ge 20 ]; then icon="󰁼"; color=$YELLOW
else icon="󰁺"; color=$RED
fi
sketchybar --set "$NAME" drawing=on icon="$icon" icon.color=$color label="$pct%"
