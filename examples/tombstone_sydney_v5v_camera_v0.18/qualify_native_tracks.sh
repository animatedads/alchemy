#!/bin/sh
# Deterministic fail-closed tests against real V5V/Camera Behaviour data.
set -eu
[ "$#" -eq 4 ] || { echo 'USAGE qualify_native_tracks.sh frames.psv tracks.psv SHA256 framecount' >&2; exit 2; }
frames=$1 tracks=$2 sha=$3 n=$4
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
rexx=${REXX_BIN:-rexx}
"$rexx" "$base/verify_v5v_camera_tracks.rex" "$frames" "$tracks" "$sha" "$n"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
count=0
reject() {
 label=$1
 if "$rexx" "$base/verify_v5v_camera_tracks.rex" "$tmp/frames.psv" "$tmp/tracks.psv" "$sha" "$n" > "$tmp/result.log" 2>&1; then
  echo "FAIL $label: forged data admitted" >&2; exit 5
 fi
 grep -q 'SYDNEY NATIVE CAMERA RECEIPT FAIL' "$tmp/result.log" || { echo "FAIL $label: missing reason" >&2; cat "$tmp/result.log"; exit 6; }
 count=$((count+1)); echo "REJECTED $label"
}
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '3s/|OBSERVED_UNTESTED$/|TESTED/' "$tmp/frames.psv"; reject promoted_frame
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '2s/|OBSERVED_UNTESTED$/|TESTED/' "$tmp/tracks.psv"; reject promoted_track
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '3s/^1|/0|/' "$tmp/frames.psv"; reject duplicate_frame
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '2s/|sha256:[0123456789abcdef]*/|sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/tracks.psv"; reject forged_hash
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '$d' "$tmp/frames.psv"; reject missing_frame
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '3s/|DELTA|/|KEYFRAME|/' "$tmp/frames.psv"; reject wrong_keyframe
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -n '2p' "$tmp/tracks.psv" >> "$tmp/tracks.psv"; reject duplicate_track
cp "$frames" "$tmp/frames.psv"; cp "$tracks" "$tmp/tracks.psv"
sed -i '2s/|OBSERVED_UNTESTED$/|OBSERVED_UNTESTED|FERRY/' "$tmp/tracks.psv"; reject unapproved_identity_field
[ "$count" -eq 8 ] || exit 9
echo 'SYDNEY NATIVE TRACK RECEIPT NEGATIVE PASS 8/8'
