#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_ROOT:?set OOREXX_ROOT to the extracted ooRexx r13196 package root}"
: "${CODING_INTENTION_ROOT:?set CODING_INTENTION_ROOT to coding_intention_steps_v0.1-dev13 root}"
: "${INTENTION_SERVICE_ROOT:?set INTENTION_SERVICE_ROOT to oorexx_intention_service_v0.1-dev9 root}"
REXX="$OOREXX_ROOT/usr/local/bin/rexx"
REXXC="$OOREXX_ROOT/usr/local/bin/rexxc"
BIN="$OOREXX_ROOT/usr/local/bin"
LIB="$OOREXX_ROOT/usr/local/lib/ooRexx"
export LD_LIBRARY_PATH="$OOREXX_ROOT/usr/local/lib:${LD_LIBRARY_PATH:-}"

"$REXX" -v | head -4
"$REXX" -v | head -1 | grep -q '5.3.0 r13196' || { echo 'ERROR: qualification requires ooRexx 5.3.0 r13196' >&2; exit 3; }

# Coding Intention dev13 vendors its own Intention Service line.  Query its
# language-knowledge object in a separate activity and export only structured
# catalogue data; the workbench runtime then loads Intention Service dev9.
CAT_TMP="$(mktemp)"
(
  export REXX_PATH="$CODING_INTENTION_ROOT:$BIN:$LIB"
  cd "$ROOT"
  "$REXX" tools/export_coding_intention_catalogue.rex "$CAT_TMP"
)
cmp -s "$CAT_TMP" "$ROOT/config/coding_intention_dev13_rexx_catalogue.json" || {
  echo 'FAIL checked-in Coding Intention language catalogue differs from live dev13 projection' >&2
  rm -f "$CAT_TMP"; exit 4;
}
rm -f "$CAT_TMP"
echo 'PASS Coding Intention dev13 structured language + class/method contract projection'

export LLM_CODING_CATALOGUE="$ROOT/config/coding_intention_dev13_rexx_catalogue.json"
INT="$INTENTION_SERVICE_ROOT"
export REXX_PATH="$ROOT/src:$ROOT/tests:$INT/src:$INT/src/nlp:$BIN:$LIB:${REXX_PATH:-}"

echo '--- WORKBENCH SYNTAX ---'
for f in "$ROOT"/src/*.cls \
         "$ROOT"/tests/test_structured_workbench.rex \
         "$ROOT"/tests/test_api_client_luna_transport.rex \
         "$ROOT"/tests/test_one_action_and_body_only.rex \
         "$ROOT"/tests/test_failure_repair_loop.rex \
         "$ROOT"/tests/test_session_action_contracts.rex \
         "$ROOT"/tests/test_semantic_coding_steps.rex \
         "$ROOT"/tests/test_catalogue_semantic_operations.rex \
         "$ROOT"/tests/test_workbench_semantic_apply.rex \
         "$ROOT"/tests/test_hint_guidance.rex \
         "$ROOT"/tests/test_materialised_verifier.rex \
         "$ROOT"/tests/test_report_requires_verification.rex \
         "$ROOT"/tests/test_runtime_interrogation_contracts.rex \
         "$ROOT"/tests/test_intention_evidence_gate.rex \
         "$ROOT"/tests/test_workbench_evidence_flow.rex \
         "$ROOT"/tests/test_language_capability_projection.rex \
         "$ROOT"/tests/test_portable_collection_operations.rex \
         "$ROOT"/tests/test_rexx_object_instrumentation.rex \
         "$ROOT"/tests/test_rexx_api_boundary.rex; do
  "$REXXC" "$f" >/dev/null
  echo "PASS rexxc ${f#$ROOT/}"
done
for f in "$ROOT"/tools/generate_semantic_house.rex "$ROOT"/tools/generate_catalogue_demo.rex "$ROOT"/tools/generate_runtime_contract_demo.rex "$ROOT"/tools/export_coding_intention_catalogue.rex; do
  "$REXXC" "$f" >/dev/null
  echo "PASS rexxc ${f#$ROOT/}"
done

echo '--- WORKBENCH CORE ---'
for t in test_structured_workbench.rex \
         test_api_client_luna_transport.rex \
         test_one_action_and_body_only.rex \
         test_failure_repair_loop.rex \
         test_session_action_contracts.rex \
         test_semantic_coding_steps.rex \
         test_catalogue_semantic_operations.rex \
         test_workbench_semantic_apply.rex \
         test_hint_guidance.rex \
         test_materialised_verifier.rex \
         test_report_requires_verification.rex \
         "$ROOT"/tests/test_runtime_interrogation_contracts.rex \
         "$ROOT"/tests/test_intention_evidence_gate.rex \
         "$ROOT"/tests/test_workbench_evidence_flow.rex \
         "$ROOT"/tests/test_language_capability_projection.rex \
         "$ROOT"/tests/test_portable_collection_operations.rex \
         "$ROOT"/tests/test_rexx_object_instrumentation.rex \
         "$ROOT"/tests/test_rexx_api_boundary.rex; do
  (cd "$ROOT/tests" && "$REXX" "$t")
done

if [[ -n "${SEMANTIC_SOURCE_STORE_ROOT:-}" ]]; then
  SSS="$SEMANTIC_SOURCE_STORE_ROOT"
  export REXX_PATH="$ROOT/src:$ROOT/tests:$INT/src:$INT/src/nlp:$SSS/src:$BIN:$LIB:${REXX_PATH:-}"
  echo '--- REAL INTENTION / DESK ADAPTER ---'
  "$REXXC" "$ROOT/tests/test_real_intention_bridge.rex" >/dev/null
  echo 'PASS rexxc tests/test_real_intention_bridge.rex'
  "$REXXC" "$ROOT/tests/test_real_method_session.rex" >/dev/null
  echo 'PASS rexxc tests/test_real_method_session.rex'
  (cd "$ROOT/tests" && "$REXX" test_real_intention_bridge.rex)
  if [[ "${RUN_REAL_SEMANTIC_METHOD_SESSION:-0}" == "1" ]]; then
    "$ROOT/tools/run_real_semantic_method_session.sh"
  fi
fi


if [[ "${RUN_LOCAL_SSCS_V085_QUALIFICATION:-0}" == "1" ]]; then
  echo '--- REAL LOCAL SSCS / NOSQLSERVER V0.85 ---'
  export REXX="$REXX" REXXC="$REXXC"
  "$ROOT/tools/run_local_sscs_v085_qualification.sh"
fi

if grep -R -nE 'address[[:space:]]+system.*curl|::requires[[:space:]]+"socket\.cls"|urllib\.(request|error)|\.socket~' "$ROOT/src"; then
  echo 'FAIL forbidden parallel HTTP transport in workbench source' >&2; exit 1
fi
if grep -R -n 'METHOD_BODY .*method_body\|CLASS_NAME .*class_name' "$ROOT/src/LlmCodingIntentionGateway.cls"; then
  echo 'FAIL structured intention payload was flattened back into command text' >&2; exit 1
fi
echo 'PASS no curl/urllib/socket transport implementation'
echo 'PASS no structured coding payload flattening in Intention gateway'

echo '--- GENERATED SEMANTIC CODE ---'
TMP_GEN="$(mktemp -d)"
(cd "$ROOT/tools" && "$REXX" generate_semantic_house.rex "$TMP_GEN/semantic_house.rex")
"$REXXC" "$TMP_GEN/semantic_house.rex" >/dev/null
echo 'PASS rexxc Coding Intention generated semantic House source'
"$REXX" "$TMP_GEN/semantic_house.rex"
rm -rf "$TMP_GEN"
TMP_CAT="$(mktemp -d)"
(cd "$ROOT/tools" && "$REXX" generate_catalogue_demo.rex "$TMP_CAT/catalogue_demo.rex")
"$REXXC" "$TMP_CAT/catalogue_demo.rex" >/dev/null
echo 'PASS rexxc Coding Intention catalogue generated source'
"$REXX" "$TMP_CAT/catalogue_demo.rex"
rm -rf "$TMP_CAT"
TMP_RT="$(mktemp -d)"
(cd "$ROOT/tools" && "$REXX" generate_runtime_contract_demo.rex "$TMP_RT/runtime_contract_demo.rex")
"$REXXC" "$TMP_RT/runtime_contract_demo.rex" >/dev/null
echo 'PASS rexxc Coding Intention dev13 runtime-contract generated source'
"$REXX" "$TMP_RT/runtime_contract_demo.rex"
rm -rf "$TMP_RT"
echo 'PASS ooRexx LLM Coding Workbench dev13 environment qualification' 
