#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
URL="${1:-https://192.168.188.25:4444/video/mjpeg}"
SECONDS="${2:-10}"
FPS="${VISION_FPS:-5}"; W="${VISION_W:-55}"; H="${VISION_H:-73}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-$HOME}/vision-live.rgb"
# SOURCE_SECONDS is measured after the first decoded frame. timeout is only a
# dead-camera/network safety guard and does not define the sample duration.
timeout "$((SECONDS+20))" "$HERE/build/vision_ffmpeg_source" "$URL" "$W" "$H" "$FPS" "$SECONDS" >"$OUT"
bytes=$(wc -c <"$OUT")
frame=$((W*H*3)); frames=$((bytes/frame)); rem=$((bytes%frame))
expected=$((SECONDS*FPS))
printf 'bytes=%s frame_bytes=%s complete_frames=%s expected~=%s remainder=%s\n' "$bytes" "$frame" "$frames" "$expected" "$rem"
test "$rem" -eq 0
# Permit one frame either side because the source timestamps are not required
# to land exactly on the requested output clock.
test "$frames" -ge "$((expected-1))"
test "$frames" -le "$((expected+1))"
