#!/bin/sh
# Reasoned Thought v0.1 qualification (strawman): two worked examples.
#   1. the RexxLA attribution re-evaluation (acceptance vectors A-E)
#   2. a hierarchy of universals for discussion (Tom's men/boys/girls example)
#   3. proof-of-analysis exchange (one proof, a second instance re-runs and diffs it)
# Pure ooRexx 5.3, no native dependencies.
# Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo "== 1. attribution re-evaluation"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_attribution_reeval.rex"
echo ""
echo "== 2. hierarchy / discussion"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_hierarchy_discussion.rex"
echo ""
echo "== 3. proof-of-analysis exchange"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_proof_exchange.rex"
echo ""
echo "REASONED THOUGHT v0.1 QUALIFICATION: PASS"
