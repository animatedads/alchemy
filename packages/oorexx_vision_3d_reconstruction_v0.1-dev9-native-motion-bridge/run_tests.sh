#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXX:=rexx}"
: "${MATHS_REXX_DIR:?set MATHS_REXX_DIR to oorexx_maths_v0.8/rexx}"
: "${VISION_SRC_DIR:?set VISION_SRC_DIR to oorexx_vision_v0.1-dev14-v5v-codec-highres/src}"
: "${WIRE3D_SRC_DIR:?set WIRE3D_SRC_DIR to Wire3D src directory}"
: "${LINE_ASSESSMENT_SRC_DIR:?set LINE_ASSESSMENT_SRC_DIR to Line Assessment src directory}"
export REXX_PATH="$HERE/src:$MATHS_REXX_DIR:$VISION_SRC_DIR:$WIRE3D_SRC_DIR:$LINE_ASSESSMENT_SRC_DIR${REXX_PATH:+:$REXX_PATH}"
for t in "$HERE"/tests/*.rex; do
  echo "== $(basename "$t") =="
  "$REXX" "$t"
done
