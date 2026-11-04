#!/bin/sh
# Run from any cwd, valid in packages/oorexx_slam_v0.1/bin/
# Usage: run_ptz_repo.sh USER_PTZ_SOURCE.mp4 /tmp/ptz-out
set -eu
if [ "$#" -ne 2 ]; then echo 'Usage: run_ptz_repo.sh source.mp4 outputdir' >&2; exit 2; fi
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)
video=$1
out=$2
mkdir -p "$out"
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$video" \
  -vf 'fps=1,scale=96:54:flags=area,format=gray' -an -pix_fmt gray -f rawvideo \
  "$out/ptz_1fps_96x54.gray"
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
"${REXX_BIN:-rexx}" "$root/tests/test_ptz_cycle.rex"
"${REXX_BIN:-rexx}" "$root/tests/test_ptz_anchors.rex"
"${REXX_BIN:-rexx}" "$root/tests/measure_ptz_cycle.rex" "$out/ptz_1fps_96x54.gray" | tee "$out/ptz_cycle_metrics.txt"