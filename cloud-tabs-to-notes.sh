#!/usr/bin/env bash
#
# cloud-tabs-to-notes.sh — snapshot Safari iCloud tabs from a device into a
# new Notes.app note. Useful for auditing what was open on a phone/tablet
# before clearing it, or just rescuing a tab list when iCloud sync gets weird.
#
# Usage:
#   cloud-tabs-to-notes.sh                  # list devices and their tab counts
#   cloud-tabs-to-notes.sh "Device Name"    # snapshot tabs from that device
#
# Output: a new note in Notes.app's default folder titled
#   "iPhone tabs — <Device> — YYYY-MM-DD"
# with an alphabetized clickable list of every tab.
#
# Reads ~/Library/Safari/CloudTabs.db directly (the same database Safari
# uses for the "Tabs from Other Devices" sidebar). Read-only — running this
# does not push anything back to the device or modify Safari state.

set -euo pipefail

DB="$HOME/Library/Safari/CloudTabs.db"
[[ -f "$DB" ]] || { echo "Safari CloudTabs.db not found at $DB" >&2; exit 1; }

# No args / help → show device list
if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage:
  $(basename "$0")                  # list devices with tab counts
  $(basename "$0") "Device Name"    # snapshot iCloud tabs from that device
                                    # into a new Notes.app note

Devices currently in iCloud Tabs:
EOF
    sqlite3 -separator $'\t' "$DB" "
      SELECT d.device_name, count(*)
      FROM cloud_tabs t
      JOIN cloud_tab_devices d ON t.device_uuid = d.device_uuid
      GROUP BY d.device_name
      ORDER BY 2 DESC;" \
    | awk -F'\t' '{ printf "  %5d  %s\n", $2, $1 }'
    exit 0
fi

DEVICE="$1"

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

DATE=$(date '+%Y-%m-%d')
TITLE="iPhone tabs — $DEVICE — $DATE"

# Build the HTML body in a temp file. File-passing avoids escaping the body
# into AppleScript (URLs and titles contain quotes, ampersands, etc.).
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
        # HTML-escape the title (Python's html.escape handles &, <, >, ", ')
        esc_title=$(printf '%s' "$title" \
            | python3 -c 'import sys,html; print(html.escape(sys.stdin.read()), end="")')
        printf '  <li><a href="%s">%s</a></li>\n' "$url" "$esc_title"
    done
    printf '</ol>\n'
} > "$tmp"

# Title needs minimal escaping for the AppleScript string literal.
TITLE_ESC=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')

osascript >/dev/null <<APPLESCRIPT
set bodyText to read POSIX file "$tmp" as «class utf8»
tell application "Notes"
    activate
    make new note with properties {name:"$TITLE_ESC", body:bodyText}
end tell
APPLESCRIPT

echo "Created Notes.app note: $TITLE ($COUNT tabs)"
