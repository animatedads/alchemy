#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX_BIN:-${REXX:-rexx}}"
if [[ "$REXX" != */* ]]; then
  REXX="$(command -v "$REXX" || true)"
fi
if [[ -z "$REXX" || ! -x "$REXX" ]]; then
  echo "ooRexx interpreter not found; set REXX_BIN" >&2
  exit 2
fi

RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
AI_ACCESS_ROOT="${AI_ACCESS_ROOT:-}"
AI_TOOL_BROKER_ROOT="${AI_TOOL_BROKER_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
CRYPTO_SRC="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
WLU_ROOT="${WLU_ROOT:-}"

for spec in \
  "RUNTIME_REGISTRY_ROOT:$RUNTIME_REGISTRY_ROOT/src/RuntimeRegistry.cls" \
  "AI_ACCESS_ROOT:$AI_ACCESS_ROOT/src/AIProviderAccess.cls" \
  "AI_TOOL_BROKER_ROOT:$AI_TOOL_BROKER_ROOT/src/AIToolBroker.cls" \
  "ALCHEMY_OBJECTS_ROOT:$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" \
  "CRYPTO_SRC:$CRYPTO_SRC/crypto.cls"; do
  name="${spec%%:*}"; path="${spec#*:}"
  if [[ "$path" == /* && -f "$path" ]]; then continue; fi
  echo "set $name to the required dependency root" >&2
  exit 2
done

REXX_BIN_DIR="$(cd "$(dirname "$REXX")" && pwd)"
parts=(
  "$ROOT/src"
  "$ROOT/fixtures/modules"
  "$AI_ACCESS_ROOT/src"
  "$AI_TOOL_BROKER_ROOT/src"
  "$RUNTIME_REGISTRY_ROOT/src"
  "$ALCHEMY_OBJECTS_ROOT/src"
  "$CRYPTO_SRC"
)
if [[ -n "$WLU_ROOT" ]]; then
  if [[ ! -f "$WLU_ROOT/src/WorkLoadUnits.cls" ]]; then
    echo "WLU_ROOT is set but WorkLoadUnits.cls is missing" >&2
    exit 2
  fi
  parts+=("$WLU_ROOT/src")
fi
parts+=("$REXX_BIN_DIR")
if [[ -n "${REXX_PATH:-}" ]]; then parts+=("$REXX_PATH"); fi
export REXX_PATH="$(IFS=:; echo "${parts[*]}")"
export RUNTIME_REGISTRY_ROOT AI_ACCESS_ROOT AI_TOOL_BROKER_ROOT ALCHEMY_OBJECTS_ROOT CRYPTO_SRC

echo "=== test_ai_tool_orchestrator.rex ==="
"$REXX" "$ROOT/tests/test_ai_tool_orchestrator.rex" "$ROOT"

if [[ -n "$WLU_ROOT" ]]; then
  export WLU_ROOT
  echo "=== test_ai_tool_orchestrator_wlu.rex ==="
  "$REXX" "$ROOT/tests/test_ai_tool_orchestrator_wlu.rex" "$ROOT"
else
  echo "=== test_ai_tool_orchestrator_wlu.rex: SKIP (WLU_ROOT not set) ==="
fi
