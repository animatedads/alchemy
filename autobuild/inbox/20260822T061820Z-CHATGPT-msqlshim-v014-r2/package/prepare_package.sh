#!/bin/sh
set -eu
cd "$(dirname "$0")"

test -f "${LIVE_MSQLSHIM_ROOT}/README.md"
if ! grep -q 'msqlshim v0\.14' "${LIVE_MSQLSHIM_ROOT}/README.md"; then
  echo "Expected msqlshim v0.14; live README begins:" >&2
  sed -n '1,12p' "${LIVE_MSQLSHIM_ROOT}/README.md" >&2
  exit 1
fi

rm -rf prepared/msqlshim_v0.14
mkdir -p prepared/msqlshim_v0.14
cp -a "${LIVE_MSQLSHIM_ROOT}"/. prepared/msqlshim_v0.14/

find prepared/msqlshim_v0.14 -type d -name __pycache__ -prune -exec rm -rf {} +
find prepared/msqlshim_v0.14 -type f -name '*.pyc' -delete
find prepared/msqlshim_v0.14 -type f -name '*.log' -delete
if [ -d prepared/msqlshim_v0.14/example/demo/tables ]; then
  find prepared/msqlshim_v0.14/example/demo/tables -type f -path '*/journal/*' -delete
fi
if [ -f prepared/msqlshim_v0.14/example/demo/querylog/patterns.yaml ]; then
  printf '{}\n' > prepared/msqlshim_v0.14/example/demo/querylog/patterns.yaml
fi

test -f prepared/msqlshim_v0.14/src/MySQLWireServer.cls
test -f prepared/msqlshim_v0.14/src/MySQLDeflate.cls
test -f prepared/msqlshim_v0.14/run_tests.sh
printf 'Prepared msqlshim v0.14 from %s\n' "$LIVE_MSQLSHIM_ROOT"
