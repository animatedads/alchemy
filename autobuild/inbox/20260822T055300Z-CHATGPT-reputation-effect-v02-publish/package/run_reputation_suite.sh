#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)/prepared/reputation_effect_v0.2"
[[ -d "$ROOT/tests" ]]
count=0
for test in "$ROOT/tests"/compile_smoke.rex "$ROOT/tests"/test_*.rex; do
  [[ -f "$test" ]] || continue
  echo "== $(basename "$test") =="
  rexx "$test"
  count=$((count + 1))
done
[[ "$count" -gt 1 ]] || { echo "FAIL insufficient reputation tests count=$count" >&2; exit 1; }
echo "PASS REPUTATION_EFFECT_V02_SUITE tests=$count"
