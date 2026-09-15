#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${POLICY_SRC:?set POLICY_SRC to institutional_policy_v0.8/src}"
: "${CASE_SRC:?set CASE_SRC to relationship_case_v0.2/src}"
: "${CRM_SRC:?set CRM_SRC to relationship_crm_v0.1/src}"
: "${FB_SRC:?set FB_SRC to federationbank_engine_v0.9/src}"
: "${QUEUE_SRC:?set QUEUE_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${LEGAL_SRC:?set LEGAL_SRC to legal_effect_v0.14/src}"
: "${SECURITY_SRC:?set SECURITY_SRC to security_effect_v0.10/src}"
: "${CIVIC_SRC:?set CIVIC_SRC to civicport_v0.12/src}"
: "${DB_SRC:?set DB_SRC to oorexx_db_skeleton_v0_46 root containing database_core.cls}"
: "${JMS_SRC:?set JMS_SRC to oorexx_jms_queue_bridge_v0.1-dev7-fb1/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${OOREXX_LIB:?set OOREXX_LIB to ooRexx library directory containing json.cls}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/examples:$HERE/tests:$HERE/runtime:$ALCHEMY_SRC:$POLICY_SRC:$CASE_SRC:$CRM_SRC:$FB_SRC:$QUEUE_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_raw_crm_not_authority.rex \
  test_external_signal_not_authority.rex \
  test_no_action_decision.rex \
  test_case_decision_binding.rex \
  test_scope_and_expiry.rex \
  test_core_final_authority.rex \
  test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done
