#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${CAMERA_CORE_DIR:?set CAMERA_CORE_DIR}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${NOSQL_CLS:?set NOSQL_CLS to NoSQLServer.cls}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"
: "${CRYPTO_SRC_ROOT:?set OOREXX_CRYPTO_SRC or CRYPTO_SRC}"
: "${REXX:=rexx}"
export REXX OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" CRYPTO_SRC="$CRYPTO_SRC_ROOT"
ROOT="$(cd "$HERE/.." && pwd)"
export PATH="$(dirname "$REXX"):$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$PATH"
export REXX_PATH="$ROOT:$ROOT/algorithm:$ROOT/integration:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$(dirname "$REXX")${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' '=== current stack v0.25: inherited v0.24 promoted-stack gates ==='
"$HERE/run_current_stack_rollup_v024.sh"

printf '%s\n' '=== current stack v0.25: Queue Fabric retained-authority revalidation ==='
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" \
  "$HERE/run_retained_authority_v025.sh"

printf '%s\n' '=== current stack v0.25: Legal Effect v0.10 retained consumer-time authority ==='
LEGAL_EFFECT_ROOT="$LEGAL_EFFECT_ROOT" \
RUNTIME_REGISTRY_ROOT="$RUNTIME_REGISTRY_ROOT" \
QUEUE_FABRIC_ROOT="$QUEUE_FABRIC_ROOT" \
OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" \
  "$HERE/run_legal_v010_retained_authority_v025.sh"

printf '%s\n' 'CURRENT STACK ROLL-UP V0.25-WORK: OK'
