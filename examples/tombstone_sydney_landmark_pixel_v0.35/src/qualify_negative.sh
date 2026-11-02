#!/bin/sh
# Deliberate corruptions, all must be rejected by the ooRexx admission layer.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
: "${REXX_BIN:=rexx}"
export REXX_PATH="$root${REXX_PATH:+:$REXX_PATH}"
original=$root/anchor_receipts.psv
[ -s "$original" ] || exit 2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
n=0
reject() {
 name=$1
 if "$REXX_BIN" "$root/qualify_image_landmarks.rex" "$tmp/bad.psv" "$tmp/forged_output.psv" >"$tmp/output.log" 2>&1;then
  echo "BAD: admitted $name" >&2; exit 4
 fi
 grep -q 'IMAGE_SPACE_LANDMARK_REJECT' "$tmp/output.log" || { echo "BAD: wrong exception for $name" >&2; cat "$tmp/output.log" >&2; exit 5; }
 n=$((n+1)); echo "NEGATIVE_PASS $name"
}
mutate(){ field=$1;value=$2; awk -F'|' -v OFS='|' -v field="$field" -v value="$value" 'NR==2 {$field=value} {print}' "$original" > "$tmp/bad.psv"; }
mutate 1 0; reject wrong_source_frame
mutate 2 0000000000000000000000000000000000000000000000000000000000000000; reject forged_cruise_digest
mutate 3 0000000000000000000000000000000000000000000000000000000000000000; reject forged_reference_digest
mutate 4 99; reject excessive_pixel_shift
mutate 5 9; reject excessive_y_shift
mutate 6 260; reject impossible_luma
mutate 7 1.01; reject control_fraction_over1
mutate 8 -1; reject negative_pylon_luma
mutate 9 -0.1; reject negative_pylon_fraction
mutate 10 200; reject waterfront_fraction_over1
mutate 11 impossible; reject nonnumeric_channel_fraction
mutate 12 INFERRED_WORLD_POSITION; reject forged_method
mutate 13 TESTED; reject forged_evidence_authority
awk -F'|' -v OFS='|' 'NR==1{$1="wrong_schema"}{print}' "$original" > "$tmp/bad.psv"; reject changed_schema
sed '$d' "$original" > "$tmp/bad.psv"; reject missing_frame
{ cat "$original"; sed -n '2p' "$original"; } > "$tmp/bad.psv"; reject extra_duplicate_frame
sed '2s/$/|SHIP_IDENTIFIED/' "$original" > "$tmp/bad.psv"; reject extra_identity_field
[ "$n" -eq 17 ] || exit 6
# A synthetically weakened target must ABSTAIN, not be called ship/occlusion.
mutate 9 0.002
"$REXX_BIN" "$root/qualify_image_landmarks.rex" "$tmp/bad.psv" "$tmp/abstain.psv" >"$tmp/abstain.log"
grep -q 'abstain=1' "$tmp/abstain.log"
grep -q 'REVIEW_REGISTRATION_OR_OCCLUSION_UNCERTAIN' "$tmp/abstain.psv"
# Real original data must qualify correctly and overwrite stale output.
"$REXX_BIN" "$root/qualify_image_landmarks.rex" "$original" "$tmp/valid.psv" >"$tmp/valid.log"
cmp "$root/occlusion_candidate.psv" "$tmp/valid.psv"
echo "NATIVE_OOREXX_IMAGE_GATES_PASS 17/17 tamper rejections, synthetic abstain, byte-exact replay"
