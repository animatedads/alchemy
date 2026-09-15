#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME}"
: "${MERCHANT_COLLATERAL_PROTOCOL_HOME:?set MERCHANT_COLLATERAL_PROTOCOL_HOME}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME}"
export REXX_PATH="$ROOT/src:$MERCHANT_BANK_HOME/src:$MERCHANT_COLLATERAL_PROTOCOL_HOME/src:$JOURNAL_POINTED_STATE_HOME/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_protocol_to_book.rex"
echo "PASS 1/1 Merchant Collateral Adapter tests"
