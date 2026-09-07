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
# Brave is out (Brave Sync); system prefs belong in a `defaults write`
# script, not snapshots.
#
# That scan only catches credential-shaped KEY NAMES. It cannot see PII inside
# an opaque <data> blob, which is why some domains also need a per-domain drop
# list (see domain_strip_keys) — OpenUsage stores an account email that way.
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
  "com.pilotmoon.popclip"                # PopClip — the REAL settings (98 keys:
                                         #   per-app rules, actions pane, search URLs)
  "com.pilotmoon.popclip-setapp"         # PopClip (Setapp) — only 3 keys (status bar
                                         #   position, first-launch, version). Kept
                                         #   because it carries the menu-bar position,
                                         #   but it is NOT where settings live. An
                                         #   earlier comment here claimed it held the
                                         #   extension list; it does not.
  "com.brettterpstra.marked"             # Marked 3 (direct)
  "com.brettterpstra.marked-setapp"      # Marked (Setapp)
  "com.hogbaysoftware.TaskPaper3.direct" # TaskPaper
  "ch.sudo.cyberduck"                    # Cyberduck (bookmarks live in App Support; passwords in keychain)
  "com.googlecode.iterm2"                # iTerm2 — profiles, colours, keymaps, hotkey window
  "com.robinebers.openusage"             # OpenUsage — menu-bar pins, layout, enabled providers.
                                         #   Heavily filtered: see domain_strip_keys below.
)

# Per-domain top-level keys to drop, beyond the global strip_keys. Echoes one
# key per line for the given domain; silent for domains with nothing to drop.
#
# OpenUsage: a raw export is ~50 KB of which ~84% is volatile usage data
# (providerSnapshots.v5-v9 are rewritten on every refresh — minutes apart), so
# an unfiltered snapshot would produce a churning binary diff on every run and
# bury the config. providerAccounts.v1 additionally embeds the signed-in
# account email and org inside a <data> blob, which the key-name scan above
# cannot see. Everything dropped here regenerates on first launch: accounts
# re-detect from ~/.claude and ~/.codex, snapshots refetch within a minute.
#
# Its iCloud sync does NOT cover any of this — it shares usage HISTORY between
# Macs ("one combined summary"), not settings, so the layout and menu-bar pins
# genuinely need this snapshot to survive a rebuild.
#
# Bartender: gained `wdsAuthToken` (a licensing/auth token) at some point after
# its last snapshot, which made the secret guard delete the export on every run
# — silently ending Bartender backups. The token was never committed; dropping
# the single key here restores the useful part (menu-bar layout). It re-auths on
# the restored machine.
domain_strip_keys() {
  case "$1" in
    com.surteesstudios.Bartender-setapp)
      printf '%s\n' "wdsAuthToken"
      ;;
    com.robinebers.openusage)
      printf '%s\n' \
        "openusage.providerSnapshots.v5" \
        "openusage.providerSnapshots.v6" \
        "openusage.providerSnapshots.v7" \
        "openusage.providerSnapshots.v8" \
        "openusage.providerSnapshots.v9" \
        "openusage.providerAccounts.v1" \
        "openusage.icloudSync.deviceID.v1" \
        "openusage.shellEnvSnapshot.v1" \
        "openusage.settings.lastRunVersion" \
        "SUHasLaunchedBefore" \
        "SULastCheckTime" \
        "SUUpdateGroupIdentifier"
      ;;
  esac
}

# On iTerm2 specifically: it also offers "Load preferences from a custom
# folder" (Preferences > General > Settings), which writes its plist straight
# into a directory of your choosing. That was deliberately NOT used here.
# It saves on every quit with no review step, so anything iTerm decides to
# persist would land in a PUBLIC repo unscanned. Going through this script
# keeps the credential scan below in the loop, at the cost of running it by
# hand after changing settings.
#
# Audited before adding: 9004 keys, no credentials. iTerm2 keeps AI API keys
# and the password manager in the Keychain, not in this plist, and the only
# `Command`/`Working Directory` values are shell paths and $HOME.

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
  # Per-domain drops. PlistBuddy, NOT plutil: `plutil -remove` treats "." as a
  # keypath separator, so it silently no-ops on keys that contain dots (every
  # OpenUsage key does — it reports "No value to remove at key path" and exits
  # 1). PlistBuddy nests with ":", so dots in a key name are literal.
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    /usr/libexec/PlistBuddy -c "Delete :$k" "$f" >/dev/null 2>&1 || true
  done < <(domain_strip_keys "$d")
  plutil -convert xml1 "$f"   # PlistBuddy may rewrite as binary; force XML back
  if grep -oE '<key>[^<]*</key>' "$f" | grep -qiE "$SECRET_KEY_RE"; then
    rm -f "$f"; warned=1
    printf '[SECRET] %s — export contains license/credential-looking keys; DELETED, not committing:\n' "$d"
    defaults export "$d" - 2>/dev/null | grep -oE '<key>[^<]*</key>' | grep -iE "$SECRET_KEY_RE" | sort -u | sed 's/^/         /'
    continue
  fi
  printf '[ok]   %s (%s)\n' "$d" "$(du -h "$f" | cut -f1 | tr -d ' ')"
done

# --- PopClip extensions -----------------------------------------------------
# PopClip's installed extensions are NOT in any plist -- they are .popclipext
# bundles on disk. Without these, restoring the domain above gives you PopClip's
# settings pointing at extensions that are not installed.
#
# Snapshotted rather than symlinked: PopClip rewrites this directory when you
# add or remove an extension, and a snapshot keeps the review-before-commit step
# that the secret guard depends on. Extensions are third-party code and CAN
# carry API keys in their Config.plist.
POPCLIP_EXT="$HOME/Library/Application Support/PopClip/Extensions"
if [[ -d "$POPCLIP_EXT" ]]; then
  dest="$HERE/popclip/Extensions"
  mkdir -p "$dest"
  rsync -a --delete --exclude '.DS_Store' "$POPCLIP_EXT/" "$dest/"
  # NOT the plist guard. $SECRET_KEY_RE matches key NAMES, which is right for a
  # plist (the name sits next to its value) and wrong for source code, where
  # those words are identifiers, comments and type declarations. It flagged
  # AISummarize's `type: secret` -- PopClip's declaration that an option is
  # Keychain-backed, i.e. the opposite of a leak -- and a `maxTokens = 1024`.
  #
  # Extensions get value-shaped detection instead: real credentials, not words
  # that mean credential. PopClip keeps extension secrets in the Keychain by
  # design, so a bundle should never hold one.
  SECRET_VALUE_RE='AIza[0-9A-Za-z_-]{20,}|sk-ant-[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z]{32,}'
  SECRET_VALUE_RE+='|AKIA[0-9A-Z]{16}|gh[pousr]_[0-9A-Za-z]{30,}|xox[abprs]-[0-9A-Za-z-]{20,}'
  SECRET_VALUE_RE+='|-----BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}'
  hits=$(grep -rlIE "$SECRET_VALUE_RE" "$dest" 2>/dev/null | head -5)
  if [[ -n "$hits" ]]; then
    warned=1
    printf '[SECRET] popclip extensions contain credential-looking keys; REMOVED, not committing:\n'
    printf '%s\n' "$hits" | sed "s|$dest/|         |"
    rm -rf "$dest"
  else
    printf '[ok]   popclip extensions (%s, %s bundles)\n' \
      "$(du -sh "$dest" | cut -f1 | tr -d ' ')" "$(ls -1 "$dest" | wc -l | tr -d ' ')"
  fi
fi

echo
echo "Changed snapshots (review before committing):"
git -C "$HERE" status --short prefs/ popclip/ || true
[[ $warned -eq 1 ]] && echo "NOTE: one or more domains were rejected by the secret guard — see above."
exit 0
