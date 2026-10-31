#!/bin/sh
set -eu
if [ "$#" -ne 4 ]; then echo 'USAGE: run_video.sh input.mp4 out.rgb out.psv sha256' >&2; exit 2; fi
clip="$1"; rgb="$2"; observations="$3"; source_hash="$4"
: "${VISION_SRC:?set VISION_SRC to packages/oorexx_vision/src}"
: "${CAMERA_BEHAVIOUR_SRC:?set CAMERA_BEHAVIOUR_SRC to packages/camera_behaviour_oorexx_v0.56}"
# Canonical Camera Behaviour requires AlchemyObject and Foreign Runtime paths.
export REXX_PATH="$VISION_SRC:$CAMERA_BEHAVIOUR_SRC${REXX_PATH:+:$REXX_PATH}"
actual=$(sha256sum "$clip" | cut -d' ' -f1)
[ "$actual" = "$source_hash" ] || { echo 'SOURCE SHA MISMATCH' >&2; exit 2; }
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$clip" \
 -vf 'crop=1920:1080:210:0,fps=5,scale=80:45:flags=area,format=rgb24' \
 -frames:v 26 -f rawvideo -pix_fmt rgb24 "$rgb"
[ "$(wc -c < "$rgb")" -eq 280800 ] || { echo 'RGB source adapter dimensions mismatch' >&2; exit 2; }
rexx "$(dirname "$0")/sydney_v5v_camera_motion.rex" "$rgb" "$observations" "$source_hash"
