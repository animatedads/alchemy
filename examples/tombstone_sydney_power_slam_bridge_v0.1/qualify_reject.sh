#!/bin/sh
set -eu
: "${OO_ROOT:?set OO_ROOT}"
export PATH="$OO_ROOT/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="$OO_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$(dirname "$0")${REXX_PATH:+:$REXX_PATH}"
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
rexx test_load_only.rex observations.psv > "$tmp/log"
grep -q '^ACCEPTED 12' "$tmp/log"
n=0
check() {
  name=$1
  if rexx test_load_only.rex "$tmp/forged.psv" > "$tmp/log" 2>&1; then
    echo "NEGATIVE FAILURE, admitted $name" >&2; exit 4
  fi
  n=$((n+1))
  echo "REJECTED $name"
}
cp observations.psv "$tmp/forged.psv"
sed -i '2s/OBSERVED_UNTESTED$/TESTED/' "$tmp/forged.psv"; check false_tested
cp observations.psv "$tmp/forged.psv"
sed -i '2s/CROSS_CAMERA_HYPOTHESIS_UNVERIFIED/FERRY_VERIFIED/' "$tmp/forged.psv"; check false_ferry_identity
cp observations.psv "$tmp/forged.psv"
sed -i '2s/6d2c535739dd8f96de8f16d26c9b43ed9c11654320d0d7bfc3106ecc4fa5488f/0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/forged.psv"; check forged_source
cp observations.psv "$tmp/forged.psv"
sed -i '2s/^2|/6|/' "$tmp/forged.psv"; check unknown_camera
cp observations.psv "$tmp/forged.psv"
sed -i '2s/|150|6.400000|/|150|6.400000|10.000|/' "$tmp/forged.psv"; check extra_column
cp observations.psv "$tmp/forged.psv"
sed -i '2s/|150|6.400000|5.000|/|150|6.400000|4.000|/' "$tmp/forged.psv"; check inconsistent_pts
cp observations.psv "$tmp/forged.psv"
sed -i '2s/|379|502|/|9999|502|/' "$tmp/forged.psv"; check outside_frame
cp observations.psv "$tmp/forged.psv"
sed -i '2s/|337|472|84|60|/|337|472|0|60|/' "$tmp/forged.psv"; check zero_crop
cp observations.psv "$tmp/forged.psv"
sed -n '2p' "$tmp/forged.psv" >> "$tmp/forged.psv"; check duplicate_camera_frame
cp observations.psv "$tmp/forged.psv"
sed -i '2s/38e9d64aa1c14b2fe03113b6f482006d4f44f54ad15a267c709580bfb60979e4/invalid-digest/' "$tmp/forged.psv"; check fake_crop_hash
cp observations.psv "$tmp/forged.psv"
sed -i '1s/source_pts_seconds/wall_clock/' "$tmp/forged.psv"; check changed_schema
[ "$n" -eq 11 ] || exit 6
echo "POWER SLAM / V5V NEGATIVE PASS 11/11"
