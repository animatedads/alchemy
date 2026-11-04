#!/bin/sh
set -eu
cd "$(dirname "$0")"
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
rexx tests/test_raw_motion_clock.rex
for scenario in WRONG_PTS SKIPPED_FRAME SOURCE_SWAP NONMONOTONE WRONG_RUN_COUNT WRONG_TIME_BASE; do
  log=$(mktemp)
  if rexx tests/test_raw_motion_reject.rex "$scenario" > "$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    echo "FAIL: admitted $scenario" >&2
    exit 1
  fi
  if ! grep -q 'Error 88' "$log"; then
    cat "$log" >&2
    rm -f "$log"
    echo "FAIL: wrong rejection for $scenario" >&2
    exit 1
  fi
  rm -f "$log"
  rm -f "tests/reject.samples.$scenario.tmp" "tests/reject.run.$scenario.tmp"
  echo "PASS fail-closed $scenario"
done
echo 'SPASH raw visual clock 24 positive + 6 negative PASS'
