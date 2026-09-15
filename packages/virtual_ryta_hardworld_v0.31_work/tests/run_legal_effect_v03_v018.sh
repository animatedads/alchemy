#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEGAL_EFFECT_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT to legal_effect_v0.3 root}"
export PATH="$LEGAL_EFFECT_ROOT/src:$PATH"
cd "$ROOT/tests"
rexx test_legal_effect_v03_identity_guard.rex.in
rexx test_legal_effect_v03_promotion_bridge.rex.in
rexx test_legal_effect_v03_authority_basis.rex.in
