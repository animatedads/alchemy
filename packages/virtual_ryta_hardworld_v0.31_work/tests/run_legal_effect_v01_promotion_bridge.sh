#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEGAL_EFFECT_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT to legal_effect_v0.1 root}"
TEST="$ROOT/tests/test_legal_effect_v01_promotion_bridge.rex.in"
PATH="$LEGAL_EFFECT_ROOT/src:$PATH" rexx "$TEST"
