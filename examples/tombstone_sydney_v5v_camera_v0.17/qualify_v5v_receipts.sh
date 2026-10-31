#!/bin/sh
set -eu
rexx=${REXX_BIN:-rexx}
script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/verify_v5v_full.rex
[ "$#" -eq 2 ] || { echo 'USAGE qualify_v5v_receipts.sh manly.psv earlier.psv' >&2; exit 2; }
manly=$1; earlier=$2
"$rexx" "$script" "$manly" "$earlier"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
n=0
expect_bad() {
 name=$1
 if "$rexx" "$script" "$tmp/test.psv" "$earlier" >"$tmp/${name}.log" 2>&1; then
   echo "FAIL $name: corrupt input was accepted"; cat "$tmp/${name}.log"; exit 6
 fi
 grep -q 'QUALIFICATION FAIL' "$tmp/${name}.log" || { echo "FAIL $name: no explicit reason"; exit 7; }
 n=$((n+1)); echo "NEGATIVE PASS: $name"
}
cp "$manly" "$tmp/test.psv"
sed -i '2s/|KEYFRAME|/|DELTA|/' "$tmp/test.psv"
expect_bad wrong_first_keyframe
cp "$manly" "$tmp/test.psv"
sed -i '3s/|OBSERVED_UNTESTED$/|TESTED/' "$tmp/test.psv"
expect_bad forbidden_promotion
cp "$manly" "$tmp/test.psv"
sed -i '3s/|sha256:[0123456789abcdef]*/|sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/test.psv"
expect_bad forged_source
cp "$manly" "$tmp/test.psv"
sed -i '$d' "$tmp/test.psv"
expect_bad missing_frame
cp "$manly" "$tmp/test.psv"
sed -i '3s/|DELTA|/|KEYFRAME|/' "$tmp/test.psv"
expect_bad wrong_delta_cadence
cp "$manly" "$tmp/test.psv"
sed -i '3s/^1|/0|/' "$tmp/test.psv"
expect_bad repeated_frame_index
cp "$manly" "$tmp/test.psv"
cat /dev/null >> "$tmp/test.psv"
printf '%s\n' '156|DELTA|0|0|0|0|1|sha256:2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192|OBSERVED_UNTESTED' >> "$tmp/test.psv"
expect_bad extra_frame
[ "$n" -eq 7 ] || exit 8
echo 'SYDNEY V5V RECEIPT NEGATIVE QUALIFICATION PASS: 7/7 tamper cases rejected'
