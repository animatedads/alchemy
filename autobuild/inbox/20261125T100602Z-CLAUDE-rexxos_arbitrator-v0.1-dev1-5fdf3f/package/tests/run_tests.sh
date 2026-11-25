#!/usr/bin/env bash
# rexxos_arbitrator v0.1-dev1 test runner.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
# Runs from the tests directory: ooRexx 5.2 resolves ::requires from the
# current directory, 5.3 from the script's directory.
set -euo pipefail
cd "$(dirname "$0")"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN)"; exit 2; }
echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1)"
out="$("$REXX_BIN" test_dev1.rex 2>&1)" || { echo "$out"; echo "FAIL rexxos_arbitrator v0.1-dev1"; exit 1; }
echo "$out"
n=$(printf '%s\n' "$out" | grep -c '^PASS' || true)
[ "$n" -ge 48 ] || { echo "FAIL expected at least 48 PASS lines, got $n"; exit 1; }
echo "PASS rexxos_arbitrator v0.1-dev1 ($n checks)"
