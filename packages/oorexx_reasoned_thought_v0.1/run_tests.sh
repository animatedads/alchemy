#!/bin/sh
# Reasoned Thought v0.1 qualification (strawman): two worked examples.
#   1. the RexxLA attribution re-evaluation (acceptance vectors A-E)
#   2. a hierarchy of universals for discussion (Tom's men/boys/girls example)
#   3. proof-of-analysis exchange (one proof, a second instance re-runs and diffs it)
#   4. retroactive revision (replay a claim under a new model; trace what decisions fall)
#   5. circular dogfood (the module audits its own development)
#   6. self-contained proof bundle (serialize -> parse -> rebuild -> verify, in a second process)
#   7. a real conversation's logic (psychic-spies/bitcoin chat): falsified assumptions -> revisions
#   8. a job's facts matrix under a measurement (rx2cpp cache: slowdown -> which fact was wrong)
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
echo "== 4. retroactive revision / dependency trace"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_retro_revision.rex"
echo ""
echo "== 5. circular dogfood (the module audits its own development)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_dogfood_development.rex"
echo ""
echo "== 6. self-contained proof bundle (independent-process replay + verify)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_proof_bundle.rex"
echo ""
echo "== 7. a real conversation's logic (psychic-spies / bitcoin chat)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_psychic_spies_logic.rex"
echo ""
echo "== 8. a job's facts matrix under a measurement (rx2cpp cache)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_rx2cpp_cache.rex"
echo ""
echo "REASONED THOUGHT v0.1 QUALIFICATION: PASS"
