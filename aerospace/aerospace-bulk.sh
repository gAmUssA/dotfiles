#!/usr/bin/env bash
# Bulk window operations for AeroSpace — the things that are tedious one window
# at a time. Bound in AERO mode (see aerospace.toml); each reports through the
# Hammerspoon HUD.
#
# Usage: aerospace-bulk.sh <tile-all|float-all|distribute|gather>
#
# Config is float-by-default, so `tile-all` is how a workspace becomes tiled and
# `float-all` undoes it. Nothing here touches other workspaces except
# `distribute` (which spreads outward) and `gather` (which pulls inward).
set -u

AS="$(command -v aerospace || echo /opt/homebrew/bin/aerospace)"
HUD="$(dirname -- "${BASH_SOURCE[0]}")/aerospace-hud.sh"
hud() { "$HUD" "$1" "${2:-}" >/dev/null 2>&1 || true; }

focused_ws() { "$AS" list-workspaces --focused 2>/dev/null; }
ids_here()   { "$AS" list-windows --workspace focused --format '%{window-id}' 2>/dev/null; }

case "${1:-}" in
  tile-all)
      n=0
      while read -r id; do
          [ -n "$id" ] || continue
          "$AS" layout tiling --window-id "$id" >/dev/null 2>&1 && n=$((n+1))
      done < <(ids_here)
      # Apply a real split only once every window is in the tree.
      "$AS" layout tiles horizontal vertical >/dev/null 2>&1
      "$AS" balance-sizes >/dev/null 2>&1
      hud "Tiled $n windows" "workspace $(focused_ws)"
      ;;

  float-all)
      n=0
      while read -r id; do
          [ -n "$id" ] || continue
          "$AS" layout floating --window-id "$id" >/dev/null 2>&1 && n=$((n+1))
      done < <(ids_here)
      hud "Floated $n windows" "workspace $(focused_ws)"
      ;;

  distribute)
      # Spread this workspace's windows one per EMPTY workspace, leaving the
      # first where it is. Empty-only on purpose: the first version filled 1,2,3
      # in order and dumped windows on top of workspaces that were already in
      # use, destroying an arrangement instead of extending it.
      here="$(focused_ws)"
      empties=()
      for w in 1 2 3 4 5 6 7 8 9; do
          [ "$w" = "$here" ] && continue
          [ -z "$("$AS" list-windows --workspace "$w" --format '%{window-id}' 2>/dev/null)" ] && empties+=("$w")
      done
      mapfile -t ids < <(ids_here)
      n=0; i=0
      for id in "${ids[@]:1}"; do          # keep the first window in place
          [ "$i" -lt "${#empties[@]}" ] || break
          "$AS" move-node-to-workspace --window-id "$id" "${empties[$i]}" >/dev/null 2>&1 \
              && { n=$((n+1)); i=$((i+1)); }
      done
      left=$(( ${#ids[@]} - 1 - n ))
      if [ "$left" -gt 0 ]; then
          hud "Spread $n windows — $left stayed (no empty workspace)" "one each"
      else
          hud "Spread $n windows, one per workspace" "$here kept $(( ${#ids[@]} - n ))"
      fi
      ;;

  gather)
      here="$(focused_ws)"; n=0
      for w in 1 2 3 4 5 6 7 8 9; do
          [ "$w" = "$here" ] && continue
          while read -r id; do
              [ -n "$id" ] || continue
              "$AS" move-node-to-workspace --window-id "$id" "$here" >/dev/null 2>&1 && n=$((n+1))
          done < <("$AS" list-windows --workspace "$w" --format '%{window-id}' 2>/dev/null)
      done
      hud "Gathered $n windows here" "workspace $here"
      ;;

  *)  echo "usage: ${0##*/} <tile-all|float-all|distribute|gather>" >&2; exit 2 ;;
esac
