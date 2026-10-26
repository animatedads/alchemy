#!/bin/sh
# Reasoned Thought v0.1 qualification (strawman): the RexxLA attribution re-evaluation.
# Pure ooRexx 5.3, no native dependencies.
# Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_attribution_reeval.rex"
echo "REASONED THOUGHT v0.1 QUALIFICATION: PASS"
