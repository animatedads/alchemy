#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
if [[ -z "${REXX_BIN:-}" ]]; then echo "rexx not found" >&2; exit 2; fi
AI_ACCESS_ROOT="${AI_ACCESS_ROOT:?AI_ACCESS_ROOT is required}"
SECRET_BROKER_ROOT="${SECRET_BROKER_ROOT:?SECRET_BROKER_ROOT is required}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:?ALCHEMY_OBJECTS_ROOT is required}"
CRYPTO_SRC="${CRYPTO_SRC:?CRYPTO_SRC is required by Alchemy Objects}"
OLD_REXX_PATH="${REXX_PATH:-}"
REXX_BIN_DIR="$(cd "$(dirname "$REXX_BIN")" && pwd)"
export REXX_PATH="$ROOT/src:$AI_ACCESS_ROOT/src:$SECRET_BROKER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC:$REXX_BIN_DIR${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_grok_alchemy_v08_adoption.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_grok_capability_selector.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_grok_provider.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_grok_runtime_module.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_grok_batch_provider.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_grok_batch_real_transport.rex" "$ROOT"
REXX_BIN="$REXX_BIN" "$ROOT/tests/test_real_curl.sh"

if [[ -n "${RUNTIME_REGISTRY_ROOT:-}" || -n "${WLU_ROOT:-}" ]]; then
  : "${RUNTIME_REGISTRY_ROOT:?RUNTIME_REGISTRY_ROOT is required when WLU qualification is requested}"
  : "${WLU_ROOT:?WLU_ROOT is required when WLU qualification is requested}"
  export REXX_PATH="$ROOT/src:$AI_ACCESS_ROOT/src:$SECRET_BROKER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC:$RUNTIME_REGISTRY_ROOT/src:$WLU_ROOT/src:$REXX_BIN_DIR${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
  "$REXX_BIN" "$ROOT/tests/test_grok_wlu_planner.rex" "$ROOT"
  "$REXX_BIN" "$ROOT/tests/test_grok_wlu_http.rex" "$ROOT"
  "$REXX_BIN" "$ROOT/tests/test_grok_batch_wlu_planner.rex" "$ROOT"
else
  echo "SKIP Grok WLU qualification (RUNTIME_REGISTRY_ROOT/WLU_ROOT not set)"
fi
