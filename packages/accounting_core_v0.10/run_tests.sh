#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cleanup() {
  rm -f "$ROOT/tests/tmp_accounting_store_v04.jsonl" \
        "$ROOT/tests/tmp_accounting_store_v04_tampered.jsonl" \
        "$ROOT/tests/tmp_accounting_tx_store_v04.jsonl" \
        "$ROOT/tests/tmp_accounting_scope_store_v05.jsonl" \
        "$ROOT/tests/tmp_accounting_tax_store_v06.jsonl" \
        "$ROOT/tests/tmp_accounting_settlement_store_v07.jsonl"
}
trap cleanup EXIT
cleanup
export PATH="$ROOT/src:$ROOT/tests:$ROOT/vendor/oorexx_crypto_v0.8.3/src:${PATH}"
cd "$ROOT"
for test in tests/test_*.rex; do
  echo "==> $(basename "$test")"
  rexx "$test"
done
if command -v python3 >/dev/null 2>&1; then
  echo "==> test_reference_projection.py"
  python3 tests/test_reference_projection.py
else
  echo "==> reference projection qualification skipped (python3 unavailable)"
fi
