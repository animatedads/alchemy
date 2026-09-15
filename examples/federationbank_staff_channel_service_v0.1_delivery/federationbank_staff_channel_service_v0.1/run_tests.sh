#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${CHANNEL_SRC:?set CHANNEL_SRC}"
: "${CHANNEL_EXAMPLES:?set CHANNEL_EXAMPLES}"
: "${CHANNEL_INTEGRATION:?set CHANNEL_INTEGRATION}"
: "${STAFF_SRC:?set STAFF_SRC}"
: "${STAFF_EXAMPLES:?set STAFF_EXAMPLES}"
: "${STAFF_INTEGRATION:?set STAFF_INTEGRATION}"
: "${STAFF_SERVICE_SRC:?set STAFF_SERVICE_SRC}"
: "${STAFF_SERVICE_INTEGRATION:?set STAFF_SERVICE_INTEGRATION}"
: "${REL_SRC:?set REL_SRC}"
: "${REL_EXAMPLES:?set REL_EXAMPLES}"
: "${CASE_SRC:?set CASE_SRC}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC}"
: "${POLICY_SRC:?set POLICY_SRC}"
: "${FB_SRC:?set FB_SRC}"
: "${LEGAL_SRC:?set LEGAL_SRC}"
: "${SECURITY_SRC:?set SECURITY_SRC}"
: "${CIVIC_SRC:?set CIVIC_SRC}"
: "${DB_SRC:?set DB_SRC}"
: "${QUEUE_SRC:?set QUEUE_SRC}"
: "${JMS_SRC:?set JMS_SRC}"
: "${CRYPTO_SRC:?set CRYPTO_SRC}"
: "${OOREXX_LIB:?set OOREXX_LIB}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$CHANNEL_SRC:$CHANNEL_EXAMPLES:$CHANNEL_INTEGRATION:$STAFF_SRC:$STAFF_EXAMPLES:$STAFF_INTEGRATION:$STAFF_SERVICE_SRC:$STAFF_SERVICE_INTEGRATION:$REL_SRC:$REL_EXAMPLES:$CASE_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
 test_service_direct_submit.rex \
 test_service_approval_resume.rex \
 test_service_idempotency.rex \
 test_write_ahead_core_recovery.rex \
 test_persistence_restart.rex \
 test_outbox_retry.rex \
 test_queue_persistent_recovery.rex \
 test_relationship_to_service_to_core.rex \
 test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done
