#!/bin/sh
# Tombstone v0.16: canonical Vision/V5V + Camera Behaviour, both original clips.
set -eu
[ "$#" -eq 3 ] || { echo 'USAGE: run_both.sh manly.mp4 earlier.mp4 outputdir' >&2; exit 2; }
manly=$1; earlier=$2; out=$3
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../../.." && pwd)
source="$root/examples/tombstone_sydney_v5v_camera_v0.16/sydney_v5v_camera_motion.rex"
vision="$root/packages/oorexx_vision/src"
camera="$root/packages/camera_behaviour_oorexx_v0.56"
objects="$root/packages/alchemy_objects_v0.8/src"
foreign="$root/packages/oorexx_foreign_runtime_v0.22.6/rexx"
for req in "$vision/Vision.cls" "$vision/V5VCodec.cls" "$camera/CameraFFmpegMediaSource.cls" "$camera/CameraLumaBehaviourBridge.cls" "$camera/CameraCore.cls" "$objects/AlchemyObject.cls" "$foreign/foreign.cls"; do
  [ -f "$req" ] || { echo "CANONICAL SOURCE MISSING: $req" >&2; exit 3; }
done
# This runner never reconstructs or silently substitutes project classes.
export REXX_PATH="$vision:$camera:$objects:$foreign${REXX_PATH:+:$REXX_PATH}"
rexx=${REXX_BIN:-rexx}; rexxc=${REXXC_BIN:-rexxc}
mkdir -p "$out"
"$rexx" -v > "$out/runtime.txt"
"$rexxc" "$source" -s
one() {
  movie=$1; sha=$2; label=$3
  actual=$(sha256sum "$movie" | cut -d' ' -f1)
  [ "$actual" = "$sha" ] || { echo "SOURCE SHA MISMATCH: $label" >&2; exit 4; }
  rgb="$out/$label.rgb"
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$movie" -vf 'crop=1920:1080:210:0,fps=5,scale=80:45:flags=area,format=rgb24' -f rawvideo -pix_fmt rgb24 "$rgb"
  bytes=$(wc -c < "$rgb")
  [ $((bytes % 10800)) -eq 0 ] || { echo "BAD RGB LENGTH: $label" >&2; exit 4; }
  frames=$((bytes / 10800))
  "$rexx" "$source" "$rgb" "$out/$label.frames.psv" "$sha" "$frames" "$out/$label.tracks.psv" > "$out/$label.native.log"
  [ "$(wc -l < "$out/$label.frames.psv")" -eq $((frames+1)) ] || { echo "FRAME OUTPUT COUNT MISMATCH: $label" >&2; exit 5; }
  cat "$out/$label.native.log"
}
one "$manly" 2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192 manly
one "$earlier" 6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb earlier
