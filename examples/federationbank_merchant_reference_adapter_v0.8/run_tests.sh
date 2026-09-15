#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME to federationbank_merchant_bank_v0.13 root}"
: "${NOSQLSERVER_HOME:?set NOSQLSERVER_HOME to nosqlserver_v0.79 root}"
: "${STRUCTURED_RELATION_HOME:?set STRUCTURED_RELATION_HOME to structured_relation_plugin_v0.9 root}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME to oorexx_journal_pointed_state_v0.1 root}"
: "${ALCHEMY_OBJECTS_HOME:?set ALCHEMY_OBJECTS_HOME to alchemy_objects_v0.8 root}"
: "${OOREXX_CRYPTO_HOME:?set OOREXX_CRYPTO_HOME to oorexx_crypto_v0.1 root}"
export REXX_PATH="$ROOT/src:$MERCHANT_BANK_HOME/src:$NOSQLSERVER_HOME/src:$NOSQLSERVER_HOME/tests:$STRUCTURED_RELATION_HOME/src:$JOURNAL_POINTED_STATE_HOME/src:$ALCHEMY_OBJECTS_HOME/src:$OOREXX_CRYPTO_HOME/src${REXX_PATH:+:$REXX_PATH}"
pass=0
for t in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$t")"
  "$REXX" "$t"
  pass=$((pass+1))
done
echo "PASS $pass/$pass FederationBank Merchant Reference Adapter tests"
