#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${FB_BANK_ROOT:?set FB_BANK_ROOT to FederationBank v0.9 with the ATM JSON-boundary compatibility patch applied}"
: "${JMS_BRIDGE_ROOT:?set JMS_BRIDGE_ROOT to oorexx_jms_queue_bridge_v0.1-dev7-fb1}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC}"
: "${INSTITUTIONAL_POLICY_SRC:?set INSTITUTIONAL_POLICY_SRC}"
: "${LEGAL_EFFECT_SRC:?set LEGAL_EFFECT_SRC}"
: "${SECURITY_EFFECT_SRC:?set SECURITY_EFFECT_SRC}"
: "${SECURITY_EFFECT_RUNTIME:?set SECURITY_EFFECT_RUNTIME}"
: "${DB_SKELETON_SRC:?set DB_SKELETON_SRC}"
: "${CIVICPORT_SRC:?set CIVICPORT_SRC}"

export TERM="${TERM:-xterm}"
export REXX_PATH="$ROOT/integration/oorexx:$FB_BANK_ROOT/src:$FB_BANK_ROOT/tests:$JMS_BRIDGE_ROOT/src:$JMS_BRIDGE_ROOT/tests:$SECURITY_EFFECT_SRC:$SECURITY_EFFECT_RUNTIME:$LEGAL_EFFECT_SRC:$INSTITUTIONAL_POLICY_SRC:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$DB_SKELETON_SRC:$CIVICPORT_SRC${REXX_PATH:+:$REXX_PATH}"

for test in \
  test_federationbank_queue_roundtrip.rex \
  test_federationbank_v09_offline_roundtrip.rex \
  test_federationbank_v09_partial_offline_roundtrip.rex; do
  qroot="$(mktemp -d)"
  trap 'rm -rf "$qroot"' EXIT
  FB_TEST_QUEUE_ROOT="$qroot" rexx "$ROOT/integration/oorexx/$test"
  rm -rf "$qroot"
  trap - EXIT
done
