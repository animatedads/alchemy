#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VISION="${VISION_HOME:-$HOME/downloads/oorexx_vision_v0.1-dev13-live-termux}"
test -f "$VISION/build/libvision_ffmpeg.so" || {
  echo "Vision native library not found at $VISION/build/libvision_ffmpeg.so" >&2
  echo "Set VISION_HOME to the extracted Vision dev13 directory." >&2
  exit 2
}
mkdir -p "$HERE/build"
clang -O2 -Wall -Wextra \
  -I"$VISION/native" \
  "$HERE/native/vision_live_probe.c" \
  -L"$VISION/build" -lvision_ffmpeg \
  -Wl,-rpath,"$VISION/build" \
  -o "$HERE/build/vision_live_probe"
ls -l "$HERE/build/vision_live_probe"
echo READY
