#!/bin/sh
# Alchemy Autobuild v0.5.3 acceptance. Author: Claude (Opus 5.5), 2026-11-14. Architecture: Tom Dyer.
# The gate's own ooRexx tests, v0.5.3's runner tests, then v0.5.2's acceptance unchanged
# (which re-runs v0.5.1's and v0.5's).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(cd "$HERE/../.." && pwd)}
export ALCHEMY_REPO_ROOT="$REPO"
rexx "$REPO/packages/oorexx_python_gate_v0.1/tests/test_python_gate.rex"
cd "$HERE"
python3 -m unittest -v tests.test_python_gate
sh "$REPO/packages/alchemy_autobuild_v0.5.2/run_tests.sh"
