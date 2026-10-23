#!/usr/bin/env bash
# Requires the media assets from the standalone full dev3 ZIP.
set -euo pipefail
here="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ "$#" -gt 0 ]; then dest="$1"; else dest="$HOME/.cache/service_video_playout/demo"; fi
mkdir -p -- "$dest"
for clip in C01_03 C02_01 C02_12 C08_07; do
  python3 "$here/tools/stage_webm.py" "$here/assets/$clip.webm" "$dest"
done
for image in A01_IDLE TPS_REPORT_DEMO; do
  python3 "$here/tools/stage_webm.py" --still "$here/assets/$image.png" "$dest"
done
printf 'STAGED: %s\n' "$dest"
