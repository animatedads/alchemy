#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${STAFF_SRC:?set STAFF_SRC}"
: "${STAFF_EXAMPLES:?set STAFF_EXAMPLES}"
: "${STAFF_INTEGRATION:?set STAFF_INTEGRATION}"
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
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/runtime:$HERE/tests:$STAFF_SRC:$STAFF_EXAMPLES:$STAFF_INTEGRATION:$REL_SRC:$REL_EXAMPLES:$CASE_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
 test_direct_staff_transfer.rex \
 test_maker_checker_resume.rex \
 test_relationship_decision_chain.rex \
 test_relationship_command_mismatch.rex \
 test_no_bank_action.rex \
 test_external_signal_not_origin.rex \
 test_core_final_authority.rex \
 test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done
