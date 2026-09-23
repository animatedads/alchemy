#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
  echo "usage: $0 FILE.f32 EXPECTED_SAMPLES" >&2
  exit 2
fi
file=$1
expected=$2
[ -f "$file" ] || { echo "FAIL f32 missing: $file" >&2; exit 2; }
case "$expected" in ''|*[!0-9]*) echo "FAIL expected samples must be whole number" >&2; exit 2;; esac
expected_bytes=$((expected*4))
got=$(stat -c %s "$file")
[ $((got%4)) -eq 0 ] || { echo "FAIL f32 byte geometry not divisible by 4: $got" >&2; exit 2; }
action=EXACT
if [ "$got" -gt "$expected_bytes" ]; then
  tmp="$file.trim.$$"
  dd if="$file" of="$tmp" bs=4 count="$expected" status=none
  mv "$tmp" "$file"
  action=TRIM
elif [ "$got" -lt "$expected_bytes" ]; then
  missing_bytes=$((expected_bytes-got))
  missing_samples=$((missing_bytes/4))
  dd if=/dev/zero bs=4 count="$missing_samples" status=none >> "$file"
  action=PAD_ZERO
fi
final=$(stat -c %s "$file")
[ "$final" -eq "$expected_bytes" ] || { echo "FAIL normalized f32 geometry expected_bytes=$expected_bytes got=$final" >&2; exit 2; }
printf 'action=%s\toriginal_bytes=%s\tfinal_bytes=%s\texpected_samples=%s\n' "$action" "$got" "$final" "$expected"
