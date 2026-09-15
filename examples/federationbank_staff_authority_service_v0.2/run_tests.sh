#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${STAFF_SRC:?set STAFF_SRC}"
: "${STAFF_EXAMPLES:?set STAFF_EXAMPLES}"
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
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$STAFF_SRC:$STAFF_EXAMPLES:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
 test_context_and_maker_authorise.rex \
 test_approval_workflow.rex \
 test_idempotency.rex \
 test_outbox_retry.rex \
 test_persistence_restart.rex \
 test_queue_persistent_recovery.rex \
 test_service_to_core_binding.rex \
 test_authority_scope_persistence.rex \
 test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done
