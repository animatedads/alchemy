#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT}"
: "${ACCESS_PERMISSIONS_ROOT:?set ACCESS_PERMISSIONS_ROOT}"
: "${INSTITUTIONAL_POLICY_ROOT:?set INSTITUTIONAL_POLICY_ROOT}"
: "${SECURITY_EFFECT_ROOT:?set SECURITY_EFFECT_ROOT}"

for required in \
  "$OOREXX_CRYPTO_ROOT/src/crypto.cls" \
  "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" \
  "$ACCESS_PERMISSIONS_ROOT/src/AccessPermissions.cls" \
  "$INSTITUTIONAL_POLICY_ROOT/src/InstitutionalPolicy.cls" \
  "$SECURITY_EFFECT_ROOT/src/SecurityEffect.cls"
do
  [[ -f "$required" ]] || { echo "missing dependency: $required" >&2; exit 2; }
done

REXX_BIN_DIR="$(cd "$(dirname "$(command -v "$REXX")")" && pwd)"
export REXX_PATH="$ROOT:$OOREXX_CRYPTO_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$ACCESS_PERMISSIONS_ROOT/src:$INSTITUTIONAL_POLICY_ROOT/src:$SECURITY_EFFECT_ROOT/src:$REXX_BIN_DIR${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
"$REXX" tests/test_access_permissions_adapter.rex
