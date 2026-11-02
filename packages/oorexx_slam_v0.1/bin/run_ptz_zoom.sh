#!/bin/sh
# Power SLAM v0.17 reproducible native PTZ zoom qualifier.
# Requires ffmpeg and native ooRexx; ffmpeg only decodes source video.
set -eu
if [ "$#" -ne 2 ]; then echo "Usage: $0 source-video output-directory" >&2; exit 2; fi
video=$1
output=$2
mkdir -p "$output"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)
: "${REXX_BIN:=rexx}"
command -v ffmpeg >/dev/null || { echo 'ffmpeg is missing' >&2; exit 2; }
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$video" -vf 'fps=1,scale=640:360,format=gray' \
 -an -pix_fmt gray -f rawvideo "$output/ptz_640x360_1fps.gray"
bytes=$(wc -c < "$output/ptz_640x360_1fps.gray" | tr -d '[:space:]')
if [ "$bytes" -ne 55296000 ]; then echo "Expected 240 frames, got $bytes bytes" >&2; exit 2; fi
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$root/tests/test_ptz_zoom.rex"
"$REXX_BIN" "$root/tests/measure_ptz_zoom.rex" "$output/ptz_640x360_1fps.gray" | tee "$output/ptz_zoom_measurement.txt"
echo 'Source/decoded frame data remain local; do not publish user footage.'