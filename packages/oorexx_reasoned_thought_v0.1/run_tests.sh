#!/bin/sh
# Reasoned Thought v0.1 qualification (strawman): two worked examples.
#   1. the RexxLA attribution re-evaluation (acceptance vectors A-E)
#   2. a hierarchy of universals for discussion (Tom's men/boys/girls example)
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
echo "REASONED THOUGHT v0.1 QUALIFICATION: PASS"
