#!/bin/sh
# run_tests.sh -- Autobuild acceptance for oorexx_browser_ui_kit.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 10 November 2026.
#
# Runs on a copy of the package in a temporary folder, so test output (var/) never reaches the published tree.
# The dependencies come from the repo's packages/ folder (ALCHEMY_REPO_ROOT, set by Autobuild).
#
# Always run (no network, no browser): fetch, order gate, ALCHEMYFETCH inbox loop, Boston Crab reader
#   (the last skips unless BOSTON_CRAB_DIR names a compiled Boston Crab).
# Browser suites (Chromium + the local fixtures): only with KIT_BROWSER_TESTS=1, CHROME set and
#   KIT_FIXTURES_CONF naming this machine's fixtures.local.conf (bridge_dir, wasm_assets), because a browser
#   that cannot start under a service must not turn into a final FAIL receipt.  CHROME_FLAGS is passed on.
SRC=$(cd "$(dirname "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(cd "$SRC/../.." && pwd)}
P=$REPO/packages
REXX=$(command -v rexx) || { echo "run_tests: rexx is not on PATH"; exit 1; }
W=$(mktemp -d "${TMPDIR:-/tmp}/browser-ui-kit-test.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT INT TERM
cp -R "$SRC/." "$W/"
rm -rf "$W/var"
mkdir -p "$W/var"
FR=$P/oorexx_foreign_runtime_v0.22.6
cat > "$W/var/kit.env" <<EOF
ALCHEMY_PACKAGES=$P
FOREIGN_RUNTIME_REXX=$FR/rexx
FOREIGN_RUNTIME_LIB=$FR/build
OOREXX_CLS=$(dirname "$REXX")
CHROME=${CHROME:-}
CHROME_FLAGS=${CHROME_FLAGS:-}
BROWSER_PROFILES=$W/var/profiles
EOF
echo "run_tests: packages from $P, ooRexx $REXX, working copy $W"
rc=0
for t in test_fetch test_order_gate test_alchemyfetch test_crab_reader; do
  echo "== $t"
  sh "$W/bin/kit.sh" rexx "$W/tests/$t.rex" || rc=1
done
if [ "${KIT_BROWSER_TESTS:-0}" = 1 ] && [ -n "${CHROME:-}" ] && [ -f "${KIT_FIXTURES_CONF:-}" ]; then
  cp "$KIT_FIXTURES_CONF" "$W/var/fixtures.local.conf"
  echo "== browser matrix (signed out and signed on, local fixtures)"
  sh "$W/tests/run_matrix.sh" || rc=1
else
  echo "== browser matrix: not run (set KIT_BROWSER_TESTS=1, CHROME and KIT_FIXTURES_CONF to run it)"
fi
if [ $rc = 0 ]; then echo "run_tests: OK"; else echo "run_tests: FAIL"; fi
exit $rc
