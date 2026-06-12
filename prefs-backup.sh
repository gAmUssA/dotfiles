#!/usr/bin/env bash
# prefs-backup.sh — snapshot GUI app preferences into the repo as XML plists.
#
# Why not symlinks (the Mackup approach): cfprefsd caches and rewrites plists
# under ~/Library/Preferences, replacing symlinks — macOS Sonoma+ broke that
# model for good. `defaults export` / `defaults import` go through cfprefsd's
# front door, so this is the supported way to move prefs between machines.
#
# Workflow: run this after changing app settings worth keeping, review the
# git diff, commit. On a new machine: install apps, then ./prefs-restore.sh.
#
# THIS REPO IS PUBLIC. Every export is scanned for license/serial/credential
# key names; a hit deletes the export and warns instead of committing it.
# That's also why TextExpander is NOT in the list — its prefs contain
# serialnumber/DMActivationKey/offlineUserEmail (and it cloud-syncs itself).
# Brave is out too (Brave Sync); system prefs belong in a `defaults write`
# script, not snapshots.
#
# Usage: ./prefs-backup.sh

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/prefs"
mkdir -p "$OUT"

# Domains to snapshot. Setapp installs use different domains than direct ones
# (e.g. com.pilotmoon.popclip-setapp) — missing domains are skipped with a
# note, so the same script works on machines with either flavor.
domains=(
  "com.manytricks.Moom"                  # Moom — window layouts + hotkeys
  "com.surteesstudios.Bartender-setapp"  # Bartender Pro (Setapp) — menu bar layout
  "com.bjango.istatmenus-setapp"         # iStat Menus (Setapp) — main settings
  "com.bjango.istatmenus-setapp.menubar.7" # iStat Menus — menubar item config
  "com.pilotmoon.popclip-setapp"         # PopClip (Setapp) — extensions on/off
  "com.brettterpstra.marked"             # Marked 3 (direct)
  "com.brettterpstra.marked-setapp"      # Marked (Setapp)
  "com.hogbaysoftware.TaskPaper3.direct" # TaskPaper
  "ch.sudo.cyberduck"                    # Cyberduck (bookmarks live in App Support; passwords in keychain)
)

# Key names that must never land in a public repo. Scans <key> names only —
# values are allowed to contain these words (e.g. a snippet about "tokens").
SECRET_KEY_RE='licen|serial|password|token|secret|activation|credential'

# Top-level keys stripped from every export: machine state that's useless on
# another machine. Sandbox secure bookmarks encode filesystem identifiers and
# don't transfer anyway — they only leak local paths (Marked keeps its
# recent-files list there). No-op for domains that don't have the key.
strip_keys=( "sandboxSecureBookmarks" )

installed_domains="$(defaults domains)"

echo "=== prefs-backup: ${#domains[@]} domains -> $OUT"
warned=0
for d in "${domains[@]}"; do
  if ! grep -q "$d" <<<"$installed_domains"; then
    printf '[skip] %s (domain not on this machine)\n' "$d"; continue
  fi
  f="$OUT/$d.plist"
  if ! defaults export "$d" "$f" 2>/dev/null; then
    printf '[FAIL] %s (defaults export error)\n' "$d"; continue
  fi
  plutil -convert xml1 "$f"   # guarantee git-diffable XML
  for k in "${strip_keys[@]}"; do plutil -remove "$k" "$f" >/dev/null 2>&1 || true; done
  if grep -oE '<key>[^<]*</key>' "$f" | grep -qiE "$SECRET_KEY_RE"; then
    rm -f "$f"; warned=1
    printf '[SECRET] %s — export contains license/credential-looking keys; DELETED, not committing:\n' "$d"
    defaults export "$d" - 2>/dev/null | grep -oE '<key>[^<]*</key>' | grep -iE "$SECRET_KEY_RE" | sort -u | sed 's/^/         /'
    continue
  fi
  printf '[ok]   %s (%s)\n' "$d" "$(du -h "$f" | cut -f1 | tr -d ' ')"
done

echo
echo "Changed snapshots (review before committing):"
git -C "$HERE" status --short prefs/ || true
[[ $warned -eq 1 ]] && echo "NOTE: one or more domains were rejected by the secret guard — see above."
exit 0
