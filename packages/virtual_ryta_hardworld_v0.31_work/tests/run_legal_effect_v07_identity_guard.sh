#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
RUNTIME_ROOT="${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${REXX:=rexx}"
export PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT:$PATH"
export REXX_PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_legal_effect_v07_identity_guard.rex.in
