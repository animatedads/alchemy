#!/bin/sh
# Reproduce against the FOUR actual uploaded screenshots and real source V5V.
# Usage: ./run_qualification.sh mask.png mosaic.png north_pano.png cafe_pano.png nodes.psv video.v5b
set -eu
[ "$#" -eq 6 ] || { echo 'Expected 4 PNG source screenshots + real V5V nodes and packed payload' >&2; exit 2; }
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
[ -x "$(command -v "$REXX_BIN")" ] || { echo 'ooRexx not found' >&2; exit 2; }
for pair in \
 "97ff5a02e63f6a9b72b44cd3e13d4a879f60d56bd3be38f07b11162ef6008d6b:$1" \
 "36712bffa18f620c2aff1513e3aa1b2641bf901f43bf6406bf4ba08ad13ff521:$2" \
 "a257e0b1784d24dade0d42c9c7e9010e5240388ec3b037db6f7adc72354de477:$3" \
 "b779bebb0d1372e1fef7d83c4390f709a6da3c99330309ce3cfb5d02095fb602:$4"; do
 expected=${pair%%:*}; file=${pair#*:}; actual=$(sha256sum "$file" | awk '{print $1}')
 [ "$actual" = "$expected" ] || { echo "SCREEN_SOURCE_HASH_REJECT $file" >&2; exit 3; }
done
echo 'SOURCE_IMAGE_DIGEST_PASS 4/4'
"$REXX_BIN" test_cross_slam.rex
"$REXX_BIN" verify_native_v5v.rex "$5" "$6"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
ffmpeg -nostdin -v error -i "$1" -vf 'scale=80:45:flags=area' -frames:v 1 -pix_fmt rgb24 -f rawvideo -y "$tmp/cyan80.rgb"
"$REXX_BIN" mask_screenshot80.rex "$tmp/cyan80.rgb" "$tmp/cyan80.psv" 97ff5a02e63f6a9b72b44cd3e13d4a879f60d56bd3be38f07b11162ef6008d6b
"$REXX_BIN" verify_mask80.rex "$tmp/cyan80.psv"
cmp cyan80_unregistered.psv "$tmp/cyan80.psv"
count=0
for case in FORGED_SHA FAKE_GEOTRANSFORM SURVEYED_PANO FAKE_V5V_TESTED INVALID_MASK_PIXEL CROSS_SOURCE_OVERLAP FALSE_IDENTITY INVALID_BEARING WRONG_RASTER_KIND REUSE_SOURCE_ID; do
 if "$REXX_BIN" test_bad.rex "$case" > "$tmp/negative.log" 2>&1; then
  echo "INCORRECTLY ACCEPTED $case" >&2; exit 4
 fi
 count=$((count+1))
done
cp "$tmp/cyan80.psv" "$tmp/bad.psv"
sed -i '2s/CLASS_SEMANTICS_UNVERIFIED/TESTED/' "$tmp/bad.psv"
if "$REXX_BIN" verify_mask80.rex "$tmp/bad.psv" > "$tmp/negative.log" 2>&1; then exit 4; fi
count=$((count+1))
cp "$tmp/cyan80.psv" "$tmp/bad.psv"
sed -i '$d' "$tmp/bad.psv"
if "$REXX_BIN" verify_mask80.rex "$tmp/bad.psv" > "$tmp/negative.log" 2>&1; then exit 4; fi
count=$((count+1))
echo "CROSS_ENGINE_NEGATIVE_PASS $count/12"
