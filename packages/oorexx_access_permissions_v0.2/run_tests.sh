#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to alchemy_objects_v0.8 root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to oorexx_crypto_v0.8.3 root}"
: "${POLICY_ROOT:?Set POLICY_ROOT to institutional_policy_v0.8 root}"
: "${SECURITY_EFFECT_ROOT:?Set SECURITY_EFFECT_ROOT to security_effect_v0.10 root}"
REXX_BIN="${OOREXX_REXX:-${REXX:-rexx}}"
if [[ "$REXX_BIN" == */* ]]; then
  REXX_BIN_PATH="$REXX_BIN"
else
  REXX_BIN_PATH="$(command -v "$REXX_BIN")"
fi
REXX_BIN_DIR="$(cd "$(dirname "$REXX_BIN_PATH")" && pwd)"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$POLICY_ROOT/src:$SECURITY_EFFECT_ROOT/src:$REXX_BIN_DIR${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
run() { echo ">>> $*"; "$@"; }
run "$REXX_BIN_PATH" compile_smoke.rex
run "$REXX_BIN_PATH" test_authentication_attribution.rex
run "$REXX_BIN_PATH" test_attribution_subject_binding.rex
run "$REXX_BIN_PATH" test_access_control.rex
run "$REXX_BIN_PATH" test_access_control_context.rex
run "$REXX_BIN_PATH" test_permission_security_effect.rex
run "$REXX_BIN_PATH" test_shared_policy_catalog.rex
run "$REXX_BIN_PATH" test_alchemy_security_manager_integration.rex "$ROOT/tests/protected_method_agent.rex"
run "$REXX_BIN_PATH" test_alchemy_access_control_pairing.rex "$ROOT/tests/protected_method_agent.rex"
