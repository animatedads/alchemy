#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME}"
: "${QUEUE_FABRIC_HOME:?set QUEUE_FABRIC_HOME}"
: "${ALCHEMY_OBJECTS_HOME:?set ALCHEMY_OBJECTS_HOME}"
: "${OOREXX_CRYPTO_HOME:?set OOREXX_CRYPTO_HOME}"
: "${ACCOUNTING_CORE_HOME:?set ACCOUNTING_CORE_HOME}"
export REXX_PATH="$ROOT/src:$ROOT/integration:$JOURNAL_POINTED_STATE_HOME/src:$MERCHANT_BANK_HOME/src:$QUEUE_FABRIC_HOME/src:$ALCHEMY_OBJECTS_HOME/src:$OOREXX_CRYPTO_HOME/src:$ACCOUNTING_CORE_HOME/src${REXX_PATH:+:$REXX_PATH}"
rm -f "$ROOT"/tests/tmp_vmm_accounting_*.jsonl
pass=0
for t in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$t")"
  "$REXX" "$t"
  pass=$((pass+1))
done
find "$ROOT" -maxdepth 1 -type d -name 'tmp_queue_*' -prune -exec rm -rf {} +
rm -f "$ROOT"/tests/tmp_vmm_accounting_*.jsonl
echo "PASS $pass/$pass Vector Meridian Markets tests"
