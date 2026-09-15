#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${CASH_SRC:?set CASH_SRC}"
: "${CASH_EXAMPLES:?set CASH_EXAMPLES}"
: "${STAFF_CHANNEL_SRC:?set STAFF_CHANNEL_SRC}"
: "${STAFF_CHANNEL_EXAMPLES:?set STAFF_CHANNEL_EXAMPLES}"
: "${STAFF_CHANNEL_SERVICE_SRC:?set STAFF_CHANNEL_SERVICE_SRC}"
: "${STAFF_CHANNEL_SERVICE_INTEGRATION:?set STAFF_CHANNEL_SERVICE_INTEGRATION}"
: "${STAFF_AUTH_SRC:?set STAFF_AUTH_SRC}"
: "${STAFF_AUTH_INTEGRATION:?set STAFF_AUTH_INTEGRATION}"
: "${STAFF_AUTH_SERVICE_SRC:?set STAFF_AUTH_SERVICE_SRC}"
: "${STAFF_AUTH_SERVICE_INTEGRATION:?set STAFF_AUTH_SERVICE_INTEGRATION}"
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
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$CASH_SRC:$CASH_EXAMPLES:$STAFF_CHANNEL_SRC:$STAFF_CHANNEL_EXAMPLES:$STAFF_CHANNEL_SERVICE_SRC:$STAFF_CHANNEL_SERVICE_INTEGRATION:$STAFF_AUTH_SRC:$STAFF_AUTH_INTEGRATION:$STAFF_AUTH_SERVICE_SRC:$STAFF_AUTH_SERVICE_INTEGRATION:$TILL_SRC:$TILL_SERVICE_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
for t in \
 test_core_rejection_no_cash.rex \
 test_core_transport_retry.rex \
 test_deposit_full_chain.rex \
 test_deposit_reconciliation_full_chain.rex \
 test_maker_checker_cash.rex \
 test_no_atm_semantics.rex \
 test_outbox_retry.rex \
 test_queue_persistent_recovery.rex \
 test_runtime_module.rex \
 test_service_idempotency.rex \
 test_service_restart_recovery.rex \
 test_withdrawal_compensation_full_chain.rex \
 test_withdrawal_full_chain.rex; do
  echo "== $t =="
  "$REXX_BIN" "$t"
done
