#!/bin/sh
set -eu
[ "$#" -eq 5 ] || { echo 'USAGE qualify_camera_regions.sh frames tracks regions SHA256 frameCount' >&2; exit 2; }
frames=$1 tracks=$2 regions=$3 sha=$4 n=$5
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
rexx=${REXX_BIN:-rexx}
"$rexx" "$root/verify_camera_regions.rex" "$frames" "$tracks" "$regions" "$sha" "$n"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
count=0
bad() {
 name=$1
 if "$rexx" "$root/verify_camera_regions.rex" "$frames" "$tracks" "$tmp/regions.psv" "$sha" "$n" > "$tmp/result.log" 2>&1; then
  echo "FAILED negative case $name"; exit 4
 fi
 grep -q 'NATIVE CAMERA REGION RECEIPT FAIL' "$tmp/result.log" || { cat "$tmp/result.log"; exit 5; }
 count=$((count+1)); echo "NEGATIVE PASS: $name"
}
cp "$regions" "$tmp/regions.psv"
sed -i '2s/|OBSERVED_UNTESTED$/|TESTED/' "$tmp/regions.psv"; bad forged_status
cp "$regions" "$tmp/regions.psv"
sed -i '2s/|OBSERVED_UNTESTED$/|OBSERVED_UNTESTED|FERRY/' "$tmp/regions.psv"; bad forged_identity_field
cp "$regions" "$tmp/regions.psv"
sed -i '$d' "$tmp/regions.psv"; bad missing_region
cp "$regions" "$tmp/regions.psv"
sed -n '2p' "$tmp/regions.psv" >> "$tmp/regions.psv"; bad duplicate_region
cp "$regions" "$tmp/regions.psv"
sed -i '2s/|sha256:[0123456789abcdef]*/|sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/regions.psv"; bad forged_source
cp "$regions" "$tmp/regions.psv"
sed -i '2s/^LT1|1|/LT1|999|/' "$tmp/regions.psv"; bad frame_out_of_bounds
[ "$count" -eq 6 ] || exit 7
echo 'REGION NEGATIVE QUALIFICATION PASS 6/6'
