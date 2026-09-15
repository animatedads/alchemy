#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
: "${CAMERA_CORE_DIR:?set CAMERA_CORE_DIR}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${NOSQL_CLS:?set NOSQL_CLS}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT}"
: "${OOREXX_LOGGING_ROOT:?set OOREXX_LOGGING_ROOT}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"; : "${CRYPTO_SRC_ROOT:?set crypto src}"
: "${REXX:=rexx}"
export REXX OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" CRYPTO_SRC="$CRYPTO_SRC_ROOT"
export PATH="$(dirname "$REXX"):$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_LOGGING_ROOT/src:$CRYPTO_SRC_ROOT:$PATH"
export REXX_PATH="$ROOT:$ROOT/algorithm:$ROOT/integration:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_LOGGING_ROOT/src:$CRYPTO_SRC_ROOT:$(dirname "$REXX")${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' '=== v0.29 Alchemy v0.8 preferred adoption ==='
cd "$HERE"; "$REXX" test_alchemy_v08_adoption_v029.rex
printf '%s\n' '=== v0.29 Alchemy v0.8 / Logging v0.5 cooperative interposition ==='
cd "$HERE"; "$REXX" test_alchemy_v08_logging_interposition_v029.rex
printf '%s\n' '=== v0.29 Legal reducer guard ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_legal_effect_v07_identity_guard.sh"
printf '%s\n' '=== v0.29 native live Legal authority compatibility ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_legal_effect_v010_native_promotion.sh"
printf '%s\n' '=== v0.29 Legal Effect v0.14 counterfactual non-authority ==='
cd "$HERE"; REXX_PATH="$LEGAL_EFFECT_ROOT/src:$REXX_PATH" "$REXX" test_legal_v014_counterfactual_boundary_v028.rex
printf '%s\n' '=== v0.29 authenticated Queue authority transport ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_transport_v027.sh"
printf '%s\n' '=== v0.29 Camera v0.41 bridge ==='
CAMERA_CORE_DIR="$CAMERA_CORE_DIR" "$HERE/run_camera_integration.sh"
printf '%s\n' '=== v0.29 Structured rich bridge ==='
"$HERE/run_structured_relation_plugin_v07_bridge.sh" "$STRUCTURED_RELATION_ROOT"
printf '%s\n' '=== v0.29 Structured -> NoSQL v0.77 ==='
"$HERE/run_structured_relation_plugin_v07_nosql_v071.sh" "$STRUCTURED_RELATION_ROOT" "$NOSQL_CLS"
printf '%s\n' '=== v0.29 retained-authority compatibility ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_retained_authority_v025.sh"
printf '%s\n' '=== v0.29 Legal retained consumer-time compatibility ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" "$HERE/run_legal_v010_retained_authority_v025.sh"
printf '%s\n' '=== v0.29 authenticated ledger adversaries ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_ledger_auth_v027.sh"
printf '%s\n' '=== v0.29 authenticated Legal completed-work recovery ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_legal_v010_ledger_auth_v027.sh"
printf '%s\n' 'CURRENT STACK ROLL-UP V0.29-WORK: OK'
