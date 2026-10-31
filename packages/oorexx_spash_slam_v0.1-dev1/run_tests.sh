#!/bin/sh
set -eu
cd "$(dirname "$0")"
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
rexx tests/test_spash.rex
rexx tests/test_example_search.rex
rexx tests/test_dual_mic_3d.rex
rexx tests/test_virtual_audio_execution.rex
n=0
for test_name in BAD_SAMPLE BAD_VECTOR BAD_PITCH DUPLICATE UNKNOWN_STEP NONEDGE_REPLAY CROSSFEED_REPLAY INVALID_SPEED INVALID_METHOD; do
  report=$(mktemp)
  if rexx tests/test_reject.rex "$test_name" >"$report" 2>&1; then
    cat "$report"; rm -f "$report"
    echo "FAIL: $test_name was incorrectly admitted" >&2
    exit 1
  fi
  if ! grep -q 'Error 88' "$report"; then
    cat "$report"; rm -f "$report"
    echo "FAIL: $test_name rejected for wrong reason" >&2
    exit 1
  fi
  rm -f "$report"
  n=$((n + 1))
  echo "PASS: fail-closed $test_name"
done
echo "SPASH SLAM negative admission: $n/$n PASS"


m=0
for scenario in SAME_DIGEST NO_HASH FAKE_PATH WRONG_SOURCE GUESS_CLOCK NO_CLOCK_UNCERTAINTY OVERGAIN VIRTUAL_PROMOTION NO_METHOD; do
  report=$(mktemp)
  if rexx tests/test_virtual_audio_reject.rex "$scenario" >"$report" 2>&1; then
    cat "$report"; rm -f "$report"
    echo "FAIL: virtual audio gate admitted $scenario" >&2
    exit 1
  fi
  if ! grep -q 'Error 88' "$report"; then
    cat "$report"; rm -f "$report"
    echo "FAIL: unexpected error for virtual gate $scenario" >&2
    exit 1
  fi
  rm -f "$report"
  m=$((m + 1))
  echo "PASS: virtual audio fail-closed $scenario"
done
echo "SPASH virtual audio native negative admission: $m/9 PASS"

# Source-only Candidate21 native runner admission; no private recordings required.
sh tests/test_candidate21_native_runner.sh
