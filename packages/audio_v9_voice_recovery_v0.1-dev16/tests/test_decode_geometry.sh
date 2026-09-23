#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/decode_geometry"; rm -rf "$T"; mkdir -p "$T"
# Deliberately short raw f32 becomes an exact canonical interval by explicit zero padding.
dd if=/dev/zero of="$T/short.f32" bs=4 count=7997 status=none
out=$("$ROOT/tools/normalize_f32_geometry.sh" "$T/short.f32" 8000)
[ "$(stat -c %s "$T/short.f32")" -eq 32000 ]
printf '%s' "$out" | grep -q 'action=PAD_ZERO'
# Deliberately long raw f32 is sample-trimmed, never accepted approximately.
dd if=/dev/zero of="$T/long.f32" bs=4 count=8011 status=none
out=$("$ROOT/tools/normalize_f32_geometry.sh" "$T/long.f32" 8000)
[ "$(stat -c %s "$T/long.f32")" -eq 32000 ]
printf '%s' "$out" | grep -q 'action=TRIM'
echo 'PASS test_decode_geometry assertions=4'
