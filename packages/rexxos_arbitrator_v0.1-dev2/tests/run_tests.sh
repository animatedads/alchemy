#!/usr/bin/env bash
# rexxos_arbitrator v0.1-dev2 test runner.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
# Runs from the tests directory: ooRexx 5.2 resolves ::requires from the
# current directory, 5.3 from the script's directory.
set -euo pipefail
cd "$(dirname "$0")"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN)"; exit 2; }
echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1)"
total=0
for t in test_dev1_machine.rex:48 test_dev2.rex:56; do
  f=${t%%:*}; want=${t##*:}
  echo "== $f"
  out="$("$REXX_BIN" "$f" 2>&1)" || { echo "$out"; echo "FAIL rexxos_arbitrator v0.1-dev2 ($f)"; exit 1; }
  echo "$out"
  n=$(printf '%s\n' "$out" | grep -c '^PASS' || true)
  [ "$n" -ge "$want" ] || { echo "FAIL $f: expected at least $want PASS lines, got $n"; exit 1; }
  total=$((total + n))
done
echo "PASS rexxos_arbitrator v0.1-dev2 ($total checks)"
