#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${CAMERA_CORE_DIR:?set CAMERA_CORE_DIR}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${NOSQL_CLS:?set NOSQL_CLS to NoSQLServer.cls}"
: "${REXX:=rexx}"
export REXX

printf '%s\n' '=== current stack: Legal Effect identity guard ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_effect_v07_identity_guard.sh"

printf '%s\n' '=== current stack: Queue authority execution ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_v021.sh"

printf '%s\n' '=== current stack: Camera bridge ==='
CAMERA_CORE_DIR="$CAMERA_CORE_DIR" "$HERE/run_camera_integration.sh"

printf '%s\n' '=== current stack: Structured rich bridge ==='
"$HERE/run_structured_relation_plugin_v07_bridge.sh" "$STRUCTURED_RELATION_ROOT"

printf '%s\n' '=== current stack: Structured -> NoSQL ==='
"$HERE/run_structured_relation_plugin_v07_nosql_v071.sh" "$STRUCTURED_RELATION_ROOT" "$NOSQL_CLS"

printf '%s\n' '=== current stack: Structured Git -> Legal v0.7 -> HardWorld ==='
STRUCTURED_RELATION_ROOT="$STRUCTURED_RELATION_ROOT" \
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" \
RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_structured_git_legal_promotion_v020_v07.sh"

printf '%s\n' '=== current stack: Legal v0.7 -> NoSQL ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_promotion_v07_nosql_v071.sh" "$NOSQL_CLS"

printf '%s\n' '=== current stack: runtime-bound Legal v0.7 must fail closed ==='
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT
set +e
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_effect_v07_native_promotion.sh" >"$TMP_OUT" 2>&1
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  cat "$TMP_OUT"
  echo 'FAILED: canonical Registry unexpectedly satisfied Legal runtime evidence contract' >&2
  exit 91
fi
if ! grep -q 'LEGAL_RUNTIME_EVIDENCE_REQUIRED' "$TMP_OUT"; then
  cat "$TMP_OUT"
  echo 'FAILED: runtime-bound Legal path failed for an unexpected reason' >&2
  exit 92
fi
printf '%s\n' 'LEGAL_RUNTIME_EVIDENCE_REQUIRED: expected fail-closed result confirmed'

printf '%s\n' 'CURRENT STACK ROLL-UP V0.22: OK'
