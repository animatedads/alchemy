#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REXX=${OOREXX_REXX:-rexx}
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_deployment_model.rex"
"$REXX" "$ROOT/tests/test_hosted_module_model.rex"
"$REXX" "$ROOT/tests/test_native_model.rex"
"$REXX" "$ROOT/tests/test_dependency_model.rex"
"$REXX" "$ROOT/tests/test_ssc_sealed_dependency_model.rex"
"$ROOT/tests/test_local_reconcile.sh"
"$ROOT/tests/test_dependency_namespace.sh"
"$ROOT/tests/test_rasenfalcon_identity_role.sh"
if [ -n "${SSC_ROOT:-}" ]; then
  export REXX_PATH="$ROOT/src:$SSC_ROOT/src:$SSC_ROOT${REXX_PATH:+:$REXX_PATH}"
  "$REXX" "$ROOT/tests/test_ssc_dependency_resolver.rex" "$ROOT" "$SSC_ROOT"
  "$ROOT/tests/test_ssc_dependency_cli.sh"
else
  echo "SKIP SSC dependency resolver (set SSC_ROOT for full qualification)"
fi
for f in "$ROOT"/bin/*.sh "$ROOT"/tests/*.sh "$ROOT"/run_tests.sh; do sh -n "$f"; done
echo 'PASS oorexx_deployment_v0.1-dev5'
