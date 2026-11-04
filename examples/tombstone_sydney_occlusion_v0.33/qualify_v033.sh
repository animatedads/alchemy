#!/bin/sh
set -eu
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH='' cd -- "$HERE/.." && pwd)
: "${REXX_BIN:=rexx}"
command -v "$REXX_BIN" >/dev/null || { echo 'ooRexx missing' >&2; exit 2; }
"$REXX_BIN" "$HERE/verify_occlusion_v033.rex" "$ROOT/results/all_groups.psv" "$ROOT/results/all_temporal.psv"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT HUP INT TERM
n=0
reject(){
 name=$1
 if "$REXX_BIN" "$HERE/verify_occlusion_v033.rex" "$ROOT/results/all_groups.psv" "$T/evidence.psv" > "$T/log" 2>&1; then
   echo "FAIL: forged $name accepted" >&2; exit 4
 fi
 grep -q '^V033_OCCLUSION_RECEIPT_REJECT:' "$T/log" || { echo "FAIL: test $name exited unexpectedly" >&2; cat "$T/log"; exit 5; }
 n=$((n+1)); echo "NEGATIVE_PASS $name"
}
forge(){
 col=$1 val=$2
 awk -F'|' -v OFS='|' -v col="$col" -v val="$val" 'NR==2 {$col=val} {print}' "$ROOT/results/all_temporal.psv" > "$T/evidence.psv"
}
forge 1 '0000000000000000000000000000000000000000000000000000000000000000';reject forged_source
forge 2 3;reject forged_camera
forge 3 451;reject invalid_frame
forge 4 99;reject false_group
forge 5 0;reject wrong_rectangle
forge 10 3;reject wrong_threshold
forge 11 999999;reject impossible_change_count
forge 12 7;reject false_total_area
forge 13 0.9;reject untrue_fraction
forge 14 99999;reject false_nonwater_count
forge 15 1;reject false_nonwater_area
forge 17 1;reject false_water_area
forge 18 0;reject impossible_coherence
forge 20 FERRY_VERIFIED;reject false_ferry_identity
forge 21 CAMERA_POSE_SURVEYED;reject false_geometric_authority
forge 22 TESTED;reject false_tested_weight
head -n -1 "$ROOT/results/all_temporal.psv" > "$T/evidence.psv"; reject missing_last
cp "$ROOT/results/all_temporal.psv" "$T/evidence.psv";sed -n '2p' "$T/evidence.psv" >> "$T/evidence.psv"; reject duplicate_region
[ "$n" -eq 18 ] || exit 6
echo 'V033_QUALIFICATION_NEGATIVE_PASS 18/18'
