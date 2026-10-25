#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" ]]; then
    if command -v rexx >/dev/null 2>&1; then REXX_BIN="$(command -v rexx)"; else echo 'NOT_RUN: set REXX_BIN to qualified ooRexx interpreter' >&2; exit 77; fi
fi
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
for f in test_packet.rex test_vc.rex test_negative.rex; do
  printf 'RUN %s\n' "$f"
  "$REXX_BIN" "$ROOT/tests/$f"
done
printf 'PASS X.25 dev1 full ooRexx deterministic test suite\n'