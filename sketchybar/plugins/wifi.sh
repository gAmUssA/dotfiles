#!/usr/bin/env bash
# Icon only when connected; macOS hides the SSID from processes without
# Location access, and a "<redacted>" label is worse than none.
dev=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2; exit}')
if ipconfig getifaddr "${dev:-en0}" >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="󰖩" label.drawing=off
else
  source "$CONFIG_DIR/colors.sh"
  sketchybar --set "$NAME" icon="󰖪" icon.color=$DIM label.drawing=off
fi
