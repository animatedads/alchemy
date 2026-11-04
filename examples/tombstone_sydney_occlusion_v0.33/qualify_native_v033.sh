#!/bin/sh
set -eu
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH='' cd -- "$HERE/.." && pwd)
T=$(mktemp -d);trap 'rm -rf "$T"' EXIT HUP INT TERM
cc -std=c11 -O2 -Wall -Wextra -Werror -o "$T/fg" "$HERE/v5v_occlusion_temporal_v033.c" -lm
sha=6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830
cp "$ROOT/raw/cruise_cam2_900.rgb" "$T/current.rgb"
cp "$ROOT/raw/cruise_cam2_750.rgb" "$T/previous.rgb"
cp "$ROOT/fixtures/cam2.water_mask.psv" "$T/mask.psv"
cp "$ROOT/results/all_groups.psv" "$T/groups.psv"
valid(){ "$T/fg" "$T/groups.psv" "$T/mask.psv" "$T/current.rgb" "$T/previous.rgb" "$sha" 2 900 1280 720 > "$T/record.psv" 2> "$T/log"; }
valid
cmp "$T/record.psv" "$ROOT/results/cruise_cam2_f900.psv"
n=0
reject(){
 if valid;then echo "BAD: admitted $1" >&2;exit 4;fi
 grep -q '^V033_REJECT:' "$T/log" || { echo "BAD: $1 failed without native reason" >&2;cat "$T/log";exit 5; }
 echo "NATIVE_NEGATIVE_PASS $1";n=$((n+1))
}
# Corrupt one dimension/source property per case; restore before next.
printf '\000' >> "$T/current.rgb";reject oversized_raw
cp "$ROOT/raw/cruise_cam2_900.rgb" "$T/current.rgb"
truncate -s 900 "$T/previous.rgb";reject truncated_previous
cp "$ROOT/raw/cruise_cam2_750.rgb" "$T/previous.rgb"
sed -i '2s/PROVISIONAL_WATER_MOVEMENT_ONLY/TESTED/' "$T/mask.psv";reject forged_mask_status
cp "$ROOT/fixtures/cam2.water_mask.psv" "$T/mask.psv"
sed -i '5s/UNCLASSIFIED_GROUP/SHIP_VERIFIED/' "$T/groups.psv";reject forged_vessel_identity
cp "$ROOT/results/all_groups.psv" "$T/groups.psv"
truncate -s 0 "$T/groups.psv";reject missing_group_evidence
cp "$ROOT/results/all_groups.psv" "$T/groups.psv"
[ "$n" -eq 5 ] || exit 6
echo 'V033_NATIVE_NEGATIVE_PASS 5/5'
