#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?pass Shannon root}"
# Runtime release/API identities are evidence, not startup passwords.  This test
# intentionally targets the exact anti-pattern that made v0.6 reject newer,
# compatible project components before exercising their required surfaces.
PATTERN='QueueFabricBuild~VERSION[[:space:]]*\\==|NoSQLServerBuild~RELEASE[[:space:]]*\\==|LegalEffectBuild~API_VERSION[[:space:]]*\\==|WLUDBuild~API_VERSION[[:space:]]*\\=='
if grep -RInE "$PATTERN" "$ROOT/src" "$ROOT/run_rexx.sh" "$ROOT/run_tests.sh" > /tmp/shannon-hard-gates.$$; then
  echo 'FAIL: hard dependency release/API gate found' >&2
  cat /tmp/shannon-hard-gates.$$ >&2
  rm -f /tmp/shannon-hard-gates.$$
  exit 1
fi
rm -f /tmp/shannon-hard-gates.$$
echo 'PASS test_shannon_no_hard_release_gates'
