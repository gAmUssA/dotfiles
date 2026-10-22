#!/usr/bin/env bash
# Redraw every workspace item at once: focused one highlighted, empty ones
# hidden, each labelled with the icons of the apps on it (at most six).
PATH=/opt/homebrew/bin:$PATH
source "$CONFIG_DIR/icon_map.sh"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
windows=$(aerospace list-windows --all --format '%{workspace}|%{app-name}') || exit 0

args=()
for sid in 1 2 3 4 5 6 7 8 9; do
  icons=""
  while IFS='|' read -r ws app; do
    [ "$ws" = "$sid" ] || continue
    __icon_map "$app"
    case " $icons " in *" $icon_result "*) ;; *) icons="$icons $icon_result" ;; esac
  done <<< "$windows"
  icons="${icons# }"
  # Cap at six icons so a busy workspace cannot push its neighbours off the
  # pill; the rest become "+N".
  set -- $icons
  if [ $# -gt 6 ]; then
    extra=$(($# - 6)); icons="$1 $2 $3 $4 $5 $6 +$extra"
  fi

  draw=off; bg=off
  [ -n "$icons" ] && draw=on
  [ "$sid" = "$focused" ] && draw=on && bg=on
  lbl=off; [ -n "$icons" ] && lbl=on
  args+=(--set "space.$sid" "drawing=$draw" "background.drawing=$bg" "label=$icons" "label.drawing=$lbl")
done
sketchybar "${args[@]}"
