#!/bin/bash
# obs4k — launch OBS straight into a 4K recording with the right profile.
#
# Profiles (created 2026-08-27, see Settings > Output in OBS):
#   hevc    -> "HVEC 4K"   HEVC hardware, ~30 GB/hour  (default; long sessions)
#   prores  -> "ProRes 4K" ProRes 422 hw, ~250 GB/hour (short takes / grading)
#
# Usage:
#   obs4k             # start recording with the HEVC profile
#   obs4k prores      # start recording with the ProRes profile
#   obs4k latest      # print (and reveal) the newest recording
#
# Stopping: use OBS itself (Stop Recording button / hotkey). The CLI flags
# only work at launch — if OBS is already running, this script tells you
# instead of silently doing nothing.
set -euo pipefail

MOVIES="$HOME/Movies"

case "${1:-hevc}" in
  hevc|hvec) PROFILE="HVEC 4K" ;;
  prores)    PROFILE="ProRes 4K" ;;
  latest)
    f=$(ls -t "$MOVIES"/*.mov 2>/dev/null | head -1)
    [[ -n "$f" ]] || { echo "no recordings in $MOVIES" >&2; exit 1; }
    echo "$f"
    open -R "$f"
    exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown arg: $1 (hevc|prores|latest)" >&2; exit 1 ;;
esac

if pgrep -xq OBS; then
  echo "OBS is already running — launch flags won't apply." >&2
  echo "Switch profile in OBS (Profile menu > $PROFILE) and hit Record there," >&2
  echo "or quit OBS and re-run obs4k." >&2
  exit 1
fi

echo "Starting OBS: profile '$PROFILE', recording immediately..."
open -a OBS --args --profile "$PROFILE" --startrecording --minimize-to-tray
