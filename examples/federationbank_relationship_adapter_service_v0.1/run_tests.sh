#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ADAPTER_SRC:?set ADAPTER_SRC}"
: "${ADAPTER_EXAMPLES:?set ADAPTER_EXAMPLES}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC}"
: "${POLICY_SRC:?set POLICY_SRC}"
: "${CASE_SRC:?set CASE_SRC}"
: "${CASE_INTEGRATION:?set CASE_INTEGRATION}"
: "${FB_SRC:?set FB_SRC}"
: "${QUEUE_SRC:?set QUEUE_SRC}"
: "${LEGAL_SRC:?set LEGAL_SRC}"
: "${SECURITY_SRC:?set SECURITY_SRC}"
: "${CIVIC_SRC:?set CIVIC_SRC}"
: "${DB_SRC:?set DB_SRC}"
: "${JMS_SRC:?set JMS_SRC}"
: "${CRYPTO_SRC:?set CRYPTO_SRC}"
: "${OOREXX_LIB:?set OOREXX_LIB}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/tests:$HERE/runtime:$ADAPTER_SRC:$ADAPTER_EXAMPLES:$ALCHEMY_SRC:$POLICY_SRC:$CASE_SRC:$CASE_INTEGRATION:$FB_SRC:$QUEUE_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
 test_submission_and_result.rex \
 test_no_action_service.rex \
 test_idempotency.rex \
 test_outbox_retry.rex \
 test_persistence_restart.rex \
 test_queue_persistent_recovery.rex \
 test_bank_queue_port_no_ledger.rex \
 test_runtime_module.rex; do
 echo "== $t =="
 "$REXX_BIN" "$HERE/tests/$t"
done
