#!/bin/sh
# Full v0.33 replay from user's untouched videos; no future frames in a
# temporal comparison.  Source hashes and byte-exact evidence mandatory.
set -eu
[ "$#" = 2 ] || { echo 'USAGE replay_v033.sh ORIGINAL_VIDEO_DIR OUTPUT_DIR' >&2; exit 2; }
VIDEO=$1
DEST=$2
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH='' cd -- "$HERE/.." && pwd)
mkdir -p "$DEST"; DEST=$(CDPATH='' cd -- "$DEST" && pwd)
: "${REXX_BIN:=rexx}"
cc -std=c11 -O2 -Wall -Wextra -Werror -o "$DEST/v5v_foreground" "$HERE/v5v_occlusion_temporal_v033.c" -lm
: > "$DEST/all_temporal.psv"
for cam in 2 3; do
 for scene in cruise baseline; do
  if [ "$scene" = cruise ]; then stamp=055436;else stamp=062311;fi
  case "$cam.$scene" in
   2.cruise) sha=6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830;w=1280;h=720;;
   2.baseline) sha=bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0;w=1280;h=720;;
   3.cruise) sha=c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e;w=640;h=360;;
   3.baseline) sha=58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d;w=640;h=360;;
  esac
  src="$VIDEO/stream${cam}_20261102T${stamp}Z.mkv"
  [ -f "$src" ] || { echo "source missing $src" >&2; exit 3; }
  actual=$(sha256sum "$src" | awk '{print $1}')
  [ "$actual" = "$sha" ] || { echo "source hash mismatch $cam $scene" >&2; exit 3; }
  sub="$DEST/${scene}_cam${cam}";mkdir -p "$sub"
  ffmpeg -nostdin -v error -i "$src" -vf "select='eq(n,300)+eq(n,450)+eq(n,750)+eq(n,900)+eq(n,1200)+eq(n,1350)'" -vsync 0 -pix_fmt rgb24 -f rawvideo -y "$sub/samples.rgb"
  pixels=$((w*h*3))
  [ "$(wc -c < "$sub/samples.rgb")" -eq "$((pixels*6))" ] || { echo 'wrong source RGB frame count' >&2; exit 3; }
  index=0
  for frame in 300 450 750 900 1200 1350; do
   dd if="$sub/samples.rgb" of="$sub/$frame.rgb" bs="$pixels" count=1 skip="$index" status=none
   index=$((index+1))
  done
  for frame in 450 900 1350; do
   "$DEST/v5v_foreground" "$ROOT/results/all_groups.psv" "$ROOT/fixtures/cam${cam}.water_mask.psv" "$sub/$frame.rgb" "$sub/$((frame-150)).rgb" "$sha" "$cam" "$frame" "$w" "$h" > "$sub/$frame.psv" 2>> "$DEST/replay.log"
   if [ ! -s "$DEST/all_temporal.psv" ]; then cp "$sub/$frame.psv" "$DEST/all_temporal.psv"; else tail -n +2 "$sub/$frame.psv" >> "$DEST/all_temporal.psv"; fi
  done
 done
done
cmp "$DEST/all_temporal.psv" "$ROOT/results/all_temporal.psv" || { echo 'FAIL: full re-extraction is not byte-identical' >&2; exit 4; }
"$REXX_BIN" "$HERE/verify_occlusion_v033.rex" "$ROOT/results/all_groups.psv" "$DEST/all_temporal.psv"
echo 'V033_FULL_CAUSAL_REPLAY_PASS 4/4 original sources, 12 frame pairs, 28 source-bound grouped regions, byte-identical'
