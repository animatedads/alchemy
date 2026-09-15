#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${MERCHANT_BANK_HOME:?set MERCHANT_BANK_HOME to federationbank_merchant_bank_v0.13 package root}"
: "${JMS_BRIDGE_HOME:?set JMS_BRIDGE_HOME to oorexx_jms_queue_bridge_v0.1-dev7-fb1 package root}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME to oorexx_journal_pointed_state_v0.1 package root}"
: "${ALCHEMY_OBJECTS_HOME:?set ALCHEMY_OBJECTS_HOME to alchemy_objects_v0.8 package root}"
: "${QUEUE_FABRIC_HOME:?set QUEUE_FABRIC_HOME to oorexx_queue_fabric_v0.9-dev4 package root}"
: "${OOREXX_CRYPTO_HOME:?set OOREXX_CRYPTO_HOME to oorexx_crypto_v0.1 package root}"
export REXX_PATH="$ROOT/src:$MERCHANT_BANK_HOME/src:$JMS_BRIDGE_HOME/src:$JOURNAL_POINTED_STATE_HOME/src:$ALCHEMY_OBJECTS_HOME/src:$QUEUE_FABRIC_HOME/src:$OOREXX_CRYPTO_HOME/src${REXX_PATH:+:$REXX_PATH}"
pass=0
for t in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$t")"
  "$REXX" "$t"
  pass=$((pass+1))
done
echo "PASS $pass/$pass FederationBank Merchant Position Service tests"
