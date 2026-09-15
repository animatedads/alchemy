#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PLUGIN_ROOT="${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
RUNTIME_ROOT="${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
: "${REXX:=rexx}"
export PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$PLUGIN_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT:$PATH"
export REXX_PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$PLUGIN_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_structured_git_legal_promotion_v020_v07.rex.in
