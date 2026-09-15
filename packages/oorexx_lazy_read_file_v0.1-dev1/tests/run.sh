#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"

cd "$ROOT/tests"
"$REXX" test_basic.rex
"$REXX" test_independent_streams.rex

fixture="$ROOT/tests/lazy-sparse-5g.bin"
rm -f "$fixture"
truncate -s $((5*1024*1024*1024+123)) "$fixture"
printf 'FOUR_GIB' | dd of="$fixture" bs=1 seek=$((4294967296+17)) conv=notrunc status=none
printf 'FIVE_GIB' | dd of="$fixture" bs=1 seek=$((5368709120+37)) conv=notrunc status=none
printf 'TAIL' | dd of="$fixture" bs=1 seek=$((5*1024*1024*1024+123-4)) conv=notrunc status=none
"$REXX" test_sparse_5g.rex "$fixture"

if [[ "${LAZY_FILE_FULL_SCAN:-0}" == "1" ]]; then
  /usr/bin/time -v "$REXX" test_scan.rex "$fixture"
fi
rm -f "$fixture"
