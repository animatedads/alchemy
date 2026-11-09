#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root/tests"
runner=${REXX:-rexx}
for name in test_temporal_mask.rex test_registration.rex
do
  echo "=== $name ==="
  "$runner" "$name"
done
if [ "${SYDNEY_JPEG_ROOT:-}" != "" ]; then
  mkdir -p "$root/outputs"
  for test in test_real_jpeg_geometry.rex test_sydney_jpeg_registration.rex
  do
    echo "=== $test ==="
    "$runner" "$test" "$SYDNEY_JPEG_ROOT"
  done
  echo '=== test_sydney_five_jpeg_temporal.rex ==='
  "$runner" test_sydney_five_jpeg_temporal.rex "$SYDNEY_JPEG_ROOT" "$root/outputs"
fi