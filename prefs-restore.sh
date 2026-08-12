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

# PopClip extensions are .popclipext bundles on disk, not plist entries, so the
# domain import above restores settings that reference extensions this machine
# may not have. Copy the bundles back too.
#
# No --delete here, unlike the backup side: this must not remove an extension
# installed only on THIS machine. It adds and updates, never destroys.
SRC="$HERE/popclip/Extensions"
if [[ -d "$SRC" ]]; then
  DST="$HOME/Library/Application Support/PopClip/Extensions"
  mkdir -p "$DST"
  if rsync -a "$SRC/" "$DST/"; then
    printf '[ok]   popclip extensions (%s bundles -> %s)\n' \
      "$(ls -1 "$SRC" | wc -l | tr -d ' ')" "$DST"
  else
    printf '[FAIL] popclip extensions\n'
  fi
fi

echo
echo "Done. Restart the affected apps (Moom, Bartender, iStat Menus, PopClip,"
echo "Marked, TaskPaper, Cyberduck, iTerm2) — they read preferences at launch."
