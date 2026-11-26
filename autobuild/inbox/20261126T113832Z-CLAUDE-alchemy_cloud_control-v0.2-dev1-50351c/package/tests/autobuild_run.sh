#!/usr/bin/env bash
# autobuild entry for alchemy_cloud_control v0.2-dev1 (Cloud Control, ooRexx).  Claude (Opus 5.5), 26 Nov 2026.
# Runs the four suites against fake provider CLIs; no cloud is touched.  The package ships no live registry, so the
# tests use tests/fixtures/registry (a redacted copy).  LOGGING_HOME is the oorexx_logging_v0.7 package.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${LOGGING_HOME:?set LOGGING_HOME to packages/oorexx_logging_v0.7}"
command -v rexx >/dev/null || { echo "FAIL rexx not on PATH"; exit 2; }
fails=0
cd "$ROOT/cloudctl/tests"
for t in test_column_display.rex test_cloudctl.rex test_discover.rex test_xtp.rex; do
  out=$(rexx "$t" "$ROOT/cloudctl" "$ROOT/cloudctl.sh" "$LOGGING_HOME" 2>&1) || true
  echo "$out" | grep -E '^FAIL' || true
  res=$(echo "$out" | grep -E '^RESULT' | tail -1)
  echo "$t: ${res:-RESULT missing}"
  case "$res" in *" fail=0") ;; *) fails=$((fails+1));; esac
done
if [ "$fails" -ne 0 ]; then echo "FAIL $fails suite(s)"; exit 1; fi
echo "PASS all four suites"
