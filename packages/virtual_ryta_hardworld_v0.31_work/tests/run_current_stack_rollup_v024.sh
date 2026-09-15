#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
: "${CAMERA_CORE_DIR:?set CAMERA_CORE_DIR}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${NOSQL_CLS:?set NOSQL_CLS to NoSQLServer.cls}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.4.3 package root}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"
: "${CRYPTO_SRC_ROOT:?set OOREXX_CRYPTO_SRC or CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${REXX:=rexx}"
export REXX OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" CRYPTO_SRC="$CRYPTO_SRC_ROOT"
export PATH="$(dirname "$REXX"):$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$PATH"
export REXX_PATH="$ROOT:$ROOT/algorithm:$ROOT/integration:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$(dirname "$REXX")${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' '=== current stack v0.24: Alchemy Objects house base ==='
cd "$HERE"
"$REXX" test_alchemy_base_v024.rex

printf '%s\n' '=== current stack v0.24: Legal reducer ambiguity guard (v0.10.1 compatibility) ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_effect_v07_identity_guard.sh"

printf '%s\n' '=== current stack v0.24: native Legal Effect v0.10 source-authority promotion ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_effect_v010_native_promotion.sh"

printf '%s\n' '=== current stack v0.24: Queue authority execution ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" "$HERE/run_queue_authority_v021.sh"

printf '%s\n' '=== current stack v0.24: Camera bridge ==='
CAMERA_CORE_DIR="$CAMERA_CORE_DIR" "$HERE/run_camera_integration.sh"

printf '%s\n' '=== current stack v0.24: Structured rich bridge ==='
"$HERE/run_structured_relation_plugin_v07_bridge.sh" "$STRUCTURED_RELATION_ROOT"

printf '%s\n' '=== current stack v0.24: Structured -> NoSQL ==='
"$HERE/run_structured_relation_plugin_v07_nosql_v071.sh" "$STRUCTURED_RELATION_ROOT" "$NOSQL_CLS"

printf '%s\n' '=== current stack v0.24: Structured Git -> legacy Legal v0.7 compatibility path ==='
STRUCTURED_RELATION_ROOT="$STRUCTURED_RELATION_ROOT" \
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" \
RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_structured_git_legal_promotion_v020_v07.sh"

printf '%s\n' '=== current stack v0.24: legacy Legal v0.7 promotion relation -> NoSQL ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
  "$HERE/run_legal_promotion_v07_nosql_v071.sh" "$NOSQL_CLS"

printf '%s\n' 'CURRENT STACK ROLL-UP V0.24-WORK: OK'
