#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC=/tmp/osc-v02-perf-test-src
REPO=/tmp/osc-v02-perf-test-repo
rm -rf "$SRC" "$REPO"
mkdir -p "$SRC"
{
  echo '::class Stress public'
  echo '::method run'
  i=1
  while [ "$i" -le 4300 ]; do
    echo "  sink~m$i($i)"
    i=$((i+1))
  done
  echo '  return 1'
} > "$SRC/Stress.cls"
cd "$ROOT"
bin/osc baseline "$SRC" --repo "$REPO" --component Stress --level 1 >/tmp/osc-v02-perf-test-first.txt
start=$(date +%s)
bin/osc baseline "$SRC" --repo "$REPO" --component Stress --level 1 >/tmp/osc-v02-perf-test-second.txt
elapsed=$(( $(date +%s) - start ))
# v0.1 was observed above 180 seconds around this snapshot size.  Keep the
# threshold deliberately generous for debug/CI hosts while guarding regression.
if [ "$elapsed" -gt 20 ]; then
  echo "FAIL identical baseline no-op took ${elapsed}s" >&2
  exit 1
fi
grep -F 'methods= 1' /tmp/osc-v02-perf-test-second.txt >/dev/null
echo "PASS test_v02_performance identicalBaselineSeconds=$elapsed"
