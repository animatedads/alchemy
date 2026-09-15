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
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"; : "${CRYPTO_SRC_ROOT:?set crypto src}"
: "${REXX:=rexx}"
export REXX OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" CRYPTO_SRC="$CRYPTO_SRC_ROOT"
export PATH="$(dirname "$REXX"):$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$PATH"
export REXX_PATH="$ROOT:$ROOT/algorithm:$ROOT/integration:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$(dirname "$REXX")${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' '=== v0.27 house-base metadata ==='
cd "$HERE"; "$REXX" test_alchemy_base_v024.rex
printf '%s\n' '=== v0.27 Legal reducer guard ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_legal_effect_v07_identity_guard.sh"
printf '%s\n' '=== v0.27 native Legal Effect v0.10 ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_legal_effect_v010_native_promotion.sh"
printf '%s\n' '=== v0.27 authenticated Queue authority transport ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_transport_v027.sh"
printf '%s\n' '=== v0.27 Camera bridge ==='
CAMERA_CORE_DIR="$CAMERA_CORE_DIR" "$HERE/run_camera_integration.sh"
printf '%s\n' '=== v0.27 Structured rich bridge ==='
"$HERE/run_structured_relation_plugin_v07_bridge.sh" "$STRUCTURED_RELATION_ROOT"
printf '%s\n' '=== v0.27 Structured -> NoSQL ==='
"$HERE/run_structured_relation_plugin_v07_nosql_v071.sh" "$STRUCTURED_RELATION_ROOT" "$NOSQL_CLS"
printf '%s\n' '=== v0.27 Structured Git -> legacy Legal compatibility ==='
STRUCTURED_RELATION_ROOT="$STRUCTURED_RELATION_ROOT" LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_structured_git_legal_promotion_v020_v07.sh"
printf '%s\n' '=== v0.27 legacy Legal promotion -> NoSQL ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" "$HERE/run_legal_promotion_v07_nosql_v071.sh" "$NOSQL_CLS"
printf '%s\n' '=== v0.27 retained-authority v0.25 compatibility ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_retained_authority_v025.sh"
printf '%s\n' '=== v0.27 Legal retained consumer-time compatibility ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" "$HERE/run_legal_v010_retained_authority_v025.sh"
printf '%s\n' '=== v0.27 authenticated ledger adversaries ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_ledger_auth_v027.sh"
printf '%s\n' '=== v0.27 authenticated Legal completed-work recovery ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_legal_v010_ledger_auth_v027.sh"
printf '%s\n' 'CURRENT STACK ROLL-UP V0.27-WORK: OK'
