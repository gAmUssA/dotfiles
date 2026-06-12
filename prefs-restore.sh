#!/usr/bin/env bash
# prefs-restore.sh — import the prefs/ snapshots into this machine's defaults.
#
# Counterpart to prefs-backup.sh. `defaults import` goes through cfprefsd, so
# no killall games are needed — but apps read prefs at launch, so QUIT the app
# first (or restart it after) for imported settings to take effect.
#
# Idempotent: re-importing the same snapshot is a no-op. Domains are derived
# from the filenames, so the list lives in prefs-backup.sh only.
#
# Usage: ./prefs-restore.sh

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IN="$HERE/prefs"

if ! ls "$IN"/*.plist >/dev/null 2>&1; then
  echo "no snapshots in $IN — run ./prefs-backup.sh on the source machine first"
  exit 1
fi

echo "=== prefs-restore: importing snapshots from $IN"
for f in "$IN"/*.plist; do
  d="$(basename "$f" .plist)"
  if defaults import "$d" "$f"; then
    printf '[ok]   %s\n' "$d"
  else
    printf '[FAIL] %s\n' "$d"
  fi
done

echo
echo "Done. Restart the affected apps (Moom, Bartender, iStat Menus, PopClip,"
echo "Marked, TaskPaper, Cyberduck) — they read preferences at launch."
