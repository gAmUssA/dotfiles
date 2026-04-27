#!/usr/bin/env bash
#
# cloud-tabs-to-notes.sh — snapshot Safari iCloud tabs from a device.
# Default sink is a new Notes.app note; --open lands them all in a fresh
# Safari window instead.
#
# Usage:
#   cloud-tabs-to-notes.sh                          # list devices and tab counts
#   cloud-tabs-to-notes.sh "Device Name"            # → new Notes.app note
#   cloud-tabs-to-notes.sh --open "Device Name"     # → new Safari window
#
# Reads ~/Library/Safari/CloudTabs.db (joins cloud_tabs ↔ cloud_tab_devices).
# Read-only — running this does not push anything back to the source device.

set -euo pipefail

# Modern Safari (sandboxed) writes iCloud Tabs to its container. The
# pre-sandbox path ~/Library/Safari/CloudTabs.db still exists on most
# machines but stopped getting updated when Safari was sandboxed —
# reading from it gives a years-stale snapshot. Prefer the container.
SANDBOX_DB="$HOME/Library/Containers/com.apple.Safari/Data/Library/Safari/CloudTabs.db"
LEGACY_DB="$HOME/Library/Safari/CloudTabs.db"

if [[ -f "$SANDBOX_DB" ]]; then
    DB="$SANDBOX_DB"
elif [[ -f "$LEGACY_DB" ]]; then
    DB="$LEGACY_DB"
    echo "warning: using legacy CloudTabs.db (pre-sandbox); data may be stale" >&2
else
    echo "Safari CloudTabs.db not found in container or legacy paths" >&2
    exit 1
fi

OPEN_IN_SAFARI=0
DEVICE=""

usage() {
    cat <<EOF
Usage:
  $(basename "$0")                          # list devices with tab counts
  $(basename "$0") "Device Name"            # snapshot tabs into a Notes.app note
  $(basename "$0") --open "Device Name"     # open all tabs in a new Safari window

Devices currently in iCloud Tabs:
EOF
    sqlite3 -separator $'\t' "$DB" "
      SELECT d.device_name, count(*)
      FROM cloud_tabs t
      JOIN cloud_tab_devices d ON t.device_uuid = d.device_uuid
      GROUP BY d.device_name
      ORDER BY 2 DESC;" \
    | awk -F'\t' '{ printf "  %5d  %s\n", $2, $1 }'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -o|--open) OPEN_IN_SAFARI=1; shift ;;
        --) shift; DEVICE="${1:-}"; shift || true; break ;;
        -*) echo "unknown option: $1" >&2; exit 1 ;;
        *)  DEVICE="$1"; shift ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    usage
    exit 0
fi

# SQL safety: escape single quotes in the device name (' → '')
DEVICE_SQL=${DEVICE//\'/\'\'}

COUNT=$(sqlite3 "$DB" "
  SELECT count(*) FROM cloud_tabs t
  JOIN cloud_tab_devices d ON t.device_uuid = d.device_uuid
  WHERE d.device_name = '$DEVICE_SQL';")

if [[ "$COUNT" -eq 0 ]]; then
    echo "No tabs found for device: $DEVICE" >&2
    echo "Run without arguments to see available devices." >&2
    exit 2
fi

# ─── Branch: open all tabs in a single new Safari window ──────────────────────
if [[ $OPEN_IN_SAFARI -eq 1 ]]; then
    urls=$(mktemp -t cloudtabs)
    trap 'rm -f "$urls"' EXIT

    sqlite3 "$DB" "
      SELECT url FROM cloud_tabs t
      JOIN cloud_tab_devices d ON t.device_uuid = d.device_uuid
      WHERE d.device_name = '$DEVICE_SQL'
      ORDER BY title COLLATE NOCASE;" > "$urls"

    # One AppleScript reads all URLs and creates the window + tabs in a single
    # invocation — much faster than spawning osascript per URL.
    osascript >/dev/null <<APPLESCRIPT
set urlsFile to POSIX file "$urls"
set urlList to paragraphs of (read urlsFile as «class utf8»)
tell application "Safari"
    activate
    set newDoc to make new document with properties {URL:item 1 of urlList}
    set theWindow to front window
    repeat with i from 2 to count of urlList
        set u to item i of urlList
        if u is not "" then
            tell theWindow to make new tab with properties {URL:u}
        end if
    end repeat
end tell
APPLESCRIPT

    echo "Opened $COUNT tabs in a new Safari window from device: $DEVICE"
    exit 0
fi

# ─── Branch (default): create a Notes.app note ────────────────────────────────
DATE=$(date '+%Y-%m-%d')
TITLE="iPhone tabs — $DEVICE — $DATE"

# File-passing avoids escaping the body into AppleScript (URLs and titles
# contain quotes, ampersands, etc.).
tmp=$(mktemp -t cloudtabs).html
trap 'rm -f "$tmp"' EXIT

{
    printf '<h1>%s</h1>\n' "$TITLE"
    printf '<p>Snapshot of iCloud tabs from <b>%s</b> on %s. %s tabs.</p>\n' \
        "$DEVICE" "$DATE" "$COUNT"
    printf '<ol>\n'
    # \x01 (SOH) as separator — won't appear in titles or URLs.
    sqlite3 -separator $'\x01' "$DB" "
      SELECT COALESCE(NULLIF(title, ''), url), url
      FROM cloud_tabs t
      JOIN cloud_tab_devices d ON t.device_uuid = d.device_uuid
      WHERE d.device_name = '$DEVICE_SQL'
      ORDER BY title COLLATE NOCASE;" \
    | while IFS=$'\x01' read -r title url; do
        esc_title=$(printf '%s' "$title" \
            | python3 -c 'import sys,html; print(html.escape(sys.stdin.read()), end="")')
        printf '  <li><a href="%s">%s</a></li>\n' "$url" "$esc_title"
    done
    printf '</ol>\n'
} > "$tmp"

TITLE_ESC=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')

osascript >/dev/null <<APPLESCRIPT
set bodyText to read POSIX file "$tmp" as «class utf8»
tell application "Notes"
    activate
    make new note with properties {name:"$TITLE_ESC", body:bodyText}
end tell
APPLESCRIPT

echo "Created Notes.app note: $TITLE ($COUNT tabs)"
