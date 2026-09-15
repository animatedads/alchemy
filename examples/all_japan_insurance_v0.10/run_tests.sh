#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ACCOUNTING_SRC="$ROOT/vendor/accounting_core_v0.7/src"
cleanup() {
  rm -f "$ROOT/tests/tmp_aji_accounting_v07.jsonl" "$ROOT/tests/tmp_aji_accounting_v08.jsonl" "$ROOT/tests/tmp_aji_accounting_v09.jsonl" "$ROOT/tests/tmp_aji_accounting_v10.jsonl"
}
trap cleanup EXIT
cleanup
export REXX_PATH="$ROOT/src:$ROOT/tests:$ACCOUNTING_SRC${REXX_PATH:+:$REXX_PATH}"
for f in "$ROOT"/src/*.cls "$ROOT"/tests/*.cls; do
  rexxc "$f" >/dev/null
  echo "COMPILE $(basename "$f")"
done
for t in "$ROOT"/tests/test_*.rex; do
  echo "=== $(basename "$t") ==="
  rexx "$t"
done
