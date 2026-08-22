#!/bin/sh
set -eu
cd "$(dirname "$0")"

test -f "${LIVE_MSQLSHIM_ROOT}/README.md"
grep -q '^# msqlshim v0\.14$' "${LIVE_MSQLSHIM_ROOT}/README.md"

rm -rf prepared/msqlshim_v0.14
mkdir -p prepared/msqlshim_v0.14
cp -a "${LIVE_MSQLSHIM_ROOT}"/. prepared/msqlshim_v0.14/

# Remove runtime/test debris before publication.
find prepared/msqlshim_v0.14 -type d -name __pycache__ -prune -exec rm -rf {} +
find prepared/msqlshim_v0.14 -type f -name '*.pyc' -delete
find prepared/msqlshim_v0.14 -type f -name '*.log' -delete

# Demo journals/query-learning files are runtime state, not source.
if [ -d prepared/msqlshim_v0.14/example/demo/tables ]; then
  find prepared/msqlshim_v0.14/example/demo/tables -type f -path '*/journal/*' -delete
fi
if [ -f prepared/msqlshim_v0.14/example/demo/querylog/patterns.yaml ]; then
  printf '{}\n' > prepared/msqlshim_v0.14/example/demo/querylog/patterns.yaml
fi

test -f prepared/msqlshim_v0.14/src/MySQLWireServer.cls
test -f prepared/msqlshim_v0.14/src/MySQLDeflate.cls
test -f prepared/msqlshim_v0.14/run_tests.sh
