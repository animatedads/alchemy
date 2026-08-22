#!/bin/sh
set -eu
[ "${PACKAGE_SCOPE_MARKER:-}" = "package-scope-ok" ] || { echo 'FAIL package scope'; exit 1; }
[ "${TEST_SCOPE_MARKER:-}" = "test-scope-ok" ] || { echo 'FAIL test scope'; exit 1; }
[ -d "${V04_PACKAGE_ROOT:-}" ] || { echo 'FAIL v0.4 package root'; exit 1; }
case "${REXX_PATH:-}" in
  *packages/alchemy_autobuild_v0.4*packages/alchemy_autobuild_v0.3*) ;;
  *) echo "FAIL REXX_PATH=$REXX_PATH"; exit 1 ;;
esac
echo "PASS V04_ENV_CONTRACT package=$PACKAGE_SCOPE_MARKER test=$TEST_SCOPE_MARKER root=$V04_PACKAGE_ROOT"
echo "REXX_PATH=$REXX_PATH"
