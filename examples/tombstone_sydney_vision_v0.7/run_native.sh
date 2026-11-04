#!/bin/sh
set -eu
D="$(cd "$(dirname "$0")" && pwd)"
cd "$D"
REXX=${REXX:-/mnt/data/oorexx_runtime/usr/local/bin/rexx}
export LD_LIBRARY_PATH="/mnt/data/oorexx_runtime/usr/local/lib:${LD_LIBRARY_PATH:-}"
"$REXX" score_vision.rex features.psv video_features.psv
