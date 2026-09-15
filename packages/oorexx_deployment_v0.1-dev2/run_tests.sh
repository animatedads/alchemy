#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REXX=${OOREXX_REXX:-rexx}
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_deployment_model.rex"
"$REXX" "$ROOT/tests/test_hosted_module_model.rex"
"$REXX" "$ROOT/tests/test_native_model.rex"
"$ROOT/tests/test_local_reconcile.sh"
for f in "$ROOT"/bin/*.sh "$ROOT"/tests/*.sh "$ROOT"/run_tests.sh; do sh -n "$f"; done
echo 'PASS oorexx_deployment_v0.1-dev2'
