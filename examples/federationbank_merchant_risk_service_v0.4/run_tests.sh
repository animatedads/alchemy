#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME to federationbank_merchant_bank_v0.13 package root}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME}"
export REXX_PATH="$ROOT/src:$ROOT/integration:$ROOT/tests:$MERCHANT_BANK_HOME/src:$JOURNAL_POINTED_STATE_HOME/src${QUEUE_FABRIC_HOME:+:$QUEUE_FABRIC_HOME/src}${ALCHEMY_OBJECTS_HOME:+:$ALCHEMY_OBJECTS_HOME/src}${OOREXX_CRYPTO_HOME:+:$OOREXX_CRYPTO_HOME/src}${REXX_PATH:+:$REXX_PATH}"
pass=0
for t in "$ROOT"/tests/test_*.rex; do
  echo "==> $(basename "$t")"
  tmp="$(mktemp -d)"; MB_RISK_TEST_ROOT="$tmp" "$REXX" "$t"; rm -rf "$tmp"; pass=$((pass+1))
done
echo "PASS $pass/$pass FederationBank Merchant Risk Service tests"
