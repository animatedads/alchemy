#!/bin/bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
v31=${V031_ROOT:-$root}
out="$root/results"
exe="$root/v5v_merge_static_v032"
rexx=${REXX_BIN:-rexx}
command -v "$rexx" >/dev/null || { echo 'ooRexx interpreter absent; set REXX_BIN/LD_LIBRARY_PATH' >&2; exit 2; }
gcc -O2 -Wall -Wextra -Werror -std=c11 "$root/source/v5v_merge_static_v032.c" -lm -o "$root/v5v_merge_static_v032"
"$rexx" "$root/source/verify_grouped_v032.rex" "$v31/evidence" "$out/all_groups.psv" "$out/grouped_crops_receipts.psv"
tmp=$(mktemp -d);trap 'rm -rf "$tmp"' EXIT
count=0
reject_rexx(){
 name=$1
 if "$rexx" "$root/source/verify_grouped_v032.rex" "$v31/evidence" "$tmp/groups.psv" "$tmp/features.psv" > "$tmp/log" 2>&1; then echo "FAIL: forged record admitted: $name" >&2;exit 5;fi
 grep -q 'V032_GROUP_REJECT:' "$tmp/log" || { cat "$tmp/log";echo "Unexpected error: $name" >&2;exit 6; }
 echo "REJECTED: $name"
 count=$((count+1))
}
setup(){ cp "$out/all_groups.psv" "$tmp/groups.psv";cp "$out/grouped_crops_receipts.psv" "$tmp/features.psv"; }
setup;sed -i '2s/OBSERVED_UNTESTED$/TESTED/' "$tmp/groups.psv";reject_rexx forged_tested
setup;sed -i '2s/UNCLASSIFIED_GROUP/FERRY_CONFIRMED/' "$tmp/groups.psv";reject_rexx forged_ship
setup;sed -i '2s/6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830/0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/groups.psv";reject_rexx forged_source
setup;sed -i '2s/|450|16.400000|/|450|15.400000|/' "$tmp/groups.psv";reject_rexx forged_timestamp
setup;sed -i '2s/|418|382|/|419|382|/' "$tmp/groups.psv";reject_rexx altered_area
setup;sed -i '2s/|418|382|/|418|383|/' "$tmp/groups.psv";reject_rexx altered_union
setup;sed -i '2s/|1,3|2|/|1,4|2|/' "$tmp/groups.psv";reject_rexx altered_members
setup;sed -i '2s/|UNKNOWN_UNSURVEYED|/|SURVEYED_POSE|/' "$tmp/groups.psv";reject_rexx forged_geometry
setup;sed -i '2s/OBSERVED_UNTESTED$/TESTED/' "$tmp/features.psv";reject_rexx forged_crop_tested
setup;sed -i '2s/|9b6d8acab28d03983f60e845e14d4c1f9e9c34a04ca27d221a78af4ca49e9825|/|invalid|/' "$tmp/features.psv";reject_rexx forged_crop_sha
setup;sed -i '2s/|640|288|352|304|/|640|288|353|304|/' "$tmp/features.psv";reject_rexx incorrect_crop_width
setup;sed -i '$d' "$tmp/groups.psv";reject_rexx missing_group
setup;sed -n '2p' "$tmp/groups.psv" >> "$tmp/groups.psv";reject_rexx duplicate_group
setup;sed -i '2s/|0.01013008|/|2.01013008|/' "$tmp/features.psv";reject_rexx impossible_brightness
# Native codec cannot accept a malformed / forged mask, V5V source authority or packed keyframe.
base="$v31/fixtures/cruise_cam3";props="$v31/evidence/cruise_cam3_proposals.psv"
cp "$v31/fixtures/cam3.water_mask.psv" "$tmp/mask.psv"
sed -i '2s/PROVISIONAL_WATER_MOVEMENT_ONLY/CERTIFIED_SURVEYED_MASK/' "$tmp/mask.psv"
if "$exe" "$base.nodes.psv" "$base.v5b" "$tmp/mask.psv" "$props" "$tmp/out.psv" > "$tmp/log" 2>&1;then echo 'FAIL forged mask admitted';exit 7;fi
count=$((count+1));echo 'REJECTED: forged_static_mask'
cp "$base.v5b" "$tmp/payload.v5b";off=$(awk -F'|' 'NR==152 {print $8}' "$base.nodes.psv");printf '\377' | dd of="$tmp/payload.v5b" bs=1 seek="$off" count=1 conv=notrunc status=none
if "$exe" "$base.nodes.psv" "$tmp/payload.v5b" "$v31/fixtures/cam3.water_mask.psv" "$props" "$tmp/out.psv" > "$tmp/log" 2>&1;then echo 'FAIL corrupted palette admitted';exit 8;fi
count=$((count+1));echo 'REJECTED: invalid_five_bit_palette'
[ "$count" -eq 16 ]
echo 'SYDNEY V032 ALL NEGATIVES PASS 16/16'
