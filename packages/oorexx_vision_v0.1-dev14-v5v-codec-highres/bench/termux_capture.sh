#!/data/data/com.termux/files/usr/bin/bash
set -eu
OUT="${1:-$HOME/vision-live}"
CAMERA="${VISION_CAMERA_ID:-0}"
mkdir -p "$OUT"
STAMP="$(date +%s%3N)"
FRAME="$OUT/vision-camera-$STAMP.jpg"
termux-camera-photo -c "$CAMERA" "$FRAME"
printf '%s\n' "$FRAME"
