#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${STAFF_CHANNEL_SRC:?set STAFF_CHANNEL_SRC}"
: "${STAFF_CHANNEL_EXAMPLES:?set STAFF_CHANNEL_EXAMPLES}"
: "${STAFF_AUTH_SRC:?set STAFF_AUTH_SRC}"
: "${STAFF_AUTH_INTEGRATION:?set STAFF_AUTH_INTEGRATION}"
: "${STAFF_AUTH_SERVICE_SRC:?set STAFF_AUTH_SERVICE_SRC}"
: "${TILL_SRC:?set TILL_SRC}"
: "${TILL_SERVICE_SRC:?set TILL_SERVICE_SRC}"
: "${FB_SRC:?set FB_SRC}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC}"
: "${POLICY_SRC:?set POLICY_SRC}"
: "${LEGAL_SRC:?set LEGAL_SRC}"
: "${SECURITY_SRC:?set SECURITY_SRC}"
: "${CIVIC_SRC:?set CIVIC_SRC}"
: "${DB_SRC:?set DB_SRC}"
: "${QUEUE_SRC:?set QUEUE_SRC}"
: "${JMS_SRC:?set JMS_SRC}"
: "${CRYPTO_SRC:?set CRYPTO_SRC}"
: "${OOREXX_LIB:?set OOREXX_LIB}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/runtime:$HERE/tests:$STAFF_CHANNEL_SRC:$STAFF_CHANNEL_EXAMPLES:$STAFF_AUTH_SRC:$STAFF_AUTH_INTEGRATION:$STAFF_AUTH_SERVICE_SRC:$TILL_SRC:$TILL_SERVICE_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
for t in \
 test_amount_binding.rex \
 test_deposit_translation.rex \
 test_instruction_immutable_registration.rex \
 test_runtime_module.rex \
 test_translator_requires_staff_authority.rex \
 test_withdrawal_translation.rex; do
  echo "== $t =="
  "$REXX_BIN" "$t"
done
