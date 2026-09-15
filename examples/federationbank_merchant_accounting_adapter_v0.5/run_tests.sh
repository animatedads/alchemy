#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${ACCOUNTING_CORE_HOME:?set ACCOUNTING_CORE_HOME to accounting_core_v0.7 package root}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME to federationbank_merchant_bank_v0.15 package root}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME to oorexx_journal_pointed_state_v0.1 package root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ACCOUNTING_CORE_HOME/src:$MERCHANT_BANK_HOME/src:$JOURNAL_POINTED_STATE_HOME/src${REXX_PATH:+:$REXX_PATH}"
rm -f "$ROOT"/tests/tmp_merchant_accounting_v*.jsonl
pass=0
for t in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$t")"
  "$REXX" "$t"
  pass=$((pass+1))
done
rm -f "$ROOT"/tests/tmp_merchant_accounting_v*.jsonl
echo "PASS $pass/$pass FederationBank Merchant Accounting Adapter tests"
