#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
WLU_ROOT="${WLU_ROOT:-}"
CRYPTO_SRC="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
ORIGINAL_REXX_PATH="${REXX_PATH:-}"

REXX_EXE="$(command -v "$REXX_BIN" 2>/dev/null || true)"
if [[ -z "$REXX_EXE" ]]; then
  echo "FAILED: ooRexx executable not found: $REXX_BIN" >&2
  exit 2
fi
REXX_BIN_DIR="$(cd "$(dirname "$REXX_EXE")" && pwd)"
REXX_NATIVE_LIB_DIR="$(cd "$REXX_BIN_DIR/../lib" 2>/dev/null && pwd || true)"
if [[ -n "$REXX_NATIVE_LIB_DIR" ]]; then
  export LD_LIBRARY_PATH="$REXX_NATIVE_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

if [[ -z "$RUNTIME_REGISTRY_ROOT" || ! -f "$RUNTIME_REGISTRY_ROOT/src/RuntimeRegistry.cls" ]]; then
  echo "FAILED: set RUNTIME_REGISTRY_ROOT to certified runtime_registry_v0.14 root" >&2
  exit 2
fi
if [[ -z "$ALCHEMY_OBJECTS_ROOT" || ! -f "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" ]]; then
  echo "FAILED: set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.7 root" >&2
  exit 2
fi
if [[ -z "$CRYPTO_SRC" || ! -f "$CRYPTO_SRC/crypto.cls" ]]; then
  echo "FAILED: set CRYPTO_SRC to oorexx_crypto_v0.1/src" >&2
  exit 2
fi
export ALCHEMY_OBJECTS_ROOT

base_parts=("$ROOT/src" "$ROOT/fixtures/modules" "$RUNTIME_REGISTRY_ROOT/src" "$ALCHEMY_OBJECTS_ROOT/src" "$CRYPTO_SRC" "$REXX_BIN_DIR")
if [[ -n "$ORIGINAL_REXX_PATH" ]]; then base_parts+=("$ORIGINAL_REXX_PATH"); fi
export REXX_PATH="$(IFS=:; echo "${base_parts[*]}")"

echo "OO REXX AI ACCESS V0.6 TESTS"
"$REXX_EXE" -v | head -4

echo "[1/5] Alchemy object adoption / non-content evidence"
"$REXX_EXE" "$ROOT/tests/test_ai_alchemy_object.rex" "$ROOT"

echo "[2/5] provider boundary contract"
"$REXX_EXE" "$ROOT/tests/test_ai_provider_contract.rex" "$ROOT"

echo "[3/5] provider-neutral tool definition/call proposal contract"
"$REXX_EXE" "$ROOT/tests/test_ai_tool_proposal.rex" "$ROOT"

echo "[4/5] structured conversation message contract"
"$REXX_EXE" "$ROOT/tests/test_ai_conversation.rex" "$ROOT"

echo "[5/5] Runtime Registry / Ability HTTP integration"
"$REXX_EXE" "$ROOT/tests/test_ai_registry_http.rex" "$ROOT"

if [[ -n "$WLU_ROOT" ]]; then
  if [[ ! -f "$WLU_ROOT/src/WorkLoadUnits.cls" ]]; then
    echo "FAILED: WLU_ROOT does not contain src/WorkLoadUnits.cls" >&2
    exit 2
  fi
  echo "[optional] WLU v0.12 admission/accounting integration"
  wlu_parts=("$ROOT/src" "$ROOT/fixtures/modules" "$RUNTIME_REGISTRY_ROOT/src" "$ALCHEMY_OBJECTS_ROOT/src" "$WLU_ROOT/src" "$CRYPTO_SRC" "$REXX_BIN_DIR")
  if [[ -n "$ORIGINAL_REXX_PATH" ]]; then wlu_parts+=("$ORIGINAL_REXX_PATH"); fi
  export REXX_PATH="$(IFS=:; echo "${wlu_parts[*]}")"
  "$REXX_EXE" "$ROOT/tests/test_ai_provider_wlu.rex" "$ROOT"
else
  echo "AI ACCESS WLU INTEGRATION: SKIP (set WLU_ROOT for current v0.12 qualification)"
fi

echo "AI ACCESS V0.6 TEST SUITE: OK"
