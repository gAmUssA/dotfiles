#!/bin/bash
# capture4k — record 4K from the Magewell USB Capture HDMI 4K Pro via ffmpeg.
#
# QuickTime caps UVC capture at 1080p unless you use ProRes "Maximum" quality;
# this records native 4K with hardware HEVC (or ProRes) instead.
#
# Measured on this rig (2026-08-27): video-only sustains a clean 29.97 fps.
# Opening ANY audio device alongside 4K video makes ffmpeg's avfoundation
# backend drop ~10-30%% of frames (worst with the Magewell's own HDMI audio,
# which also competes for the card's USB bandwidth). So audio is OFF by
# default — use OBS/Ecamm when you need synced audio, or record audio
# separately and mux in post.
#
# Usage:
#   capture4k                        # record UHD@29.97 HEVC until 'q' / Ctrl-C
#   capture4k -t 60                  # record 60 seconds
#   capture4k -o take1.mov           # explicit output file
#   capture4k --prores               # ProRes 422 instead of HEVC (huge files)
#   capture4k -s 4096x2160 -r 25     # override size / framerate
#   capture4k --audio "RODECaster Pro II Secondary"   # add audio (drops frames!)
#   capture4k --probe                # grab a single PNG frame to verify signal
#   capture4k --list                 # list modes the card advertises
set -euo pipefail

DEVICE="USB Capture HDMI 4K Pro"
SIZE="3840x2160"
RATE="29.97"
BITRATE="60M"
CODEC="hevc"
DURATION=""
OUT=""
AUDIO=""
OUTDIR="$HOME/Movies/Captures"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SIZE="$2"; shift 2 ;;
    -r) RATE="$2"; shift 2 ;;
    -b) BITRATE="$2"; shift 2 ;;
    -t) DURATION="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --audio) AUDIO="$2"; shift 2 ;;
    --prores) CODEC="prores"; shift ;;
    --probe)
      out="$OUTDIR/probe-$(date +%Y%m%d-%H%M%S).png"
      mkdir -p "$OUTDIR"
      ffmpeg -hide_banner -loglevel error -y \
        -f avfoundation -i "$DEVICE" -frames:v 1 "$out"
      echo "Frame: $out ($(sips -g pixelWidth -g pixelHeight "$out" |
        awk '/pixel/ {printf "%s ", $2}'))"
      open "$out"
      exit 0 ;;
    --list)
      # Bogus framerate makes ffmpeg dump every mode the card offers.
      ffmpeg -hide_banner -f avfoundation -framerate 1 -i "$DEVICE" 2>&1 |
        grep -oE '[0-9]+x[0-9]+@\[[0-9.]+' | sed 's/@\[/ @ /' | sort -u -V
      exit 0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1 (see --help)" >&2; exit 1 ;;
  esac
done

if [[ -z "$OUT" ]]; then
  mkdir -p "$OUTDIR"
  OUT="$OUTDIR/cap-$(date +%Y%m%d-%H%M%S).mov"
fi

case "$CODEC" in
  hevc)   venc=(-c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1) ;;
  prores) venc=(-c:v prores_videotoolbox -profile:v 2) ;;         # ProRes 422
esac

# nv12 matters: it halves USB bandwidth vs uyvy422 and skips a CPU-side
# pixel conversion that otherwise throttles 4K to ~19 fps.
vin=(-f avfoundation -framerate "$RATE" -video_size "$SIZE" -pixel_format nv12
     -i "$DEVICE")

ain=() amap=() aenc=()
if [[ -n "$AUDIO" ]]; then
  echo "warning: audio capture alongside 4K video drops frames (see --help)" >&2
  ain=(-f avfoundation -i ":${AUDIO}")
  amap=(-map 0:v -map 1:a)
  # pan= collapses odd channel layouts (e.g. RODECaster multitrack) to stereo,
  # which the aac encoder refuses otherwise.
  aenc=(-af "pan=stereo|c0=c0|c1=c1" -c:a aac -b:a 256k)
fi

dur=()
[[ -n "$DURATION" ]] && dur=(-t "$DURATION")

echo "Recording ${SIZE}@${RATE} ($CODEC) -> $OUT   [press q to stop]"
# ${arr[@]+...} keeps macOS bash 3.2's `set -u` happy when arrays are empty
ffmpeg -hide_banner -loglevel warning -stats \
  "${vin[@]}" ${ain[@]+"${ain[@]}"} ${amap[@]+"${amap[@]}"} \
  "${venc[@]}" -r "$RATE" ${aenc[@]+"${aenc[@]}"} ${dur[@]+"${dur[@]}"} "$OUT"

echo "Saved: $OUT"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,avg_frame_rate,codec_name \
  -of default=noprint_wrappers=1 "$OUT"
