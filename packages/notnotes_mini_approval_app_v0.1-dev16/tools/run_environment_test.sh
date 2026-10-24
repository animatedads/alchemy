#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
RUNTIME_ROOT=${1:-}
if [[ -z "$RUNTIME_ROOT" ]]; then
  echo "usage: $0 /path/to/extracted/usr/local" >&2
  exit 2
fi
REXX_BIN="$RUNTIME_ROOT/bin/rexx"
if [[ ! -x "$REXX_BIN" ]]; then
  echo "missing ooRexx runtime: $REXX_BIN" >&2
  exit 2
fi
export PATH="$RUNTIME_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/vendor/cliui/lib:$RUNTIME_ROOT/lib64:$RUNTIME_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/cliui/lib:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$RUNTIME_ROOT/share/ooRexx:$RUNTIME_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"

PATH="$RUNTIME_ROOT/bin:$PATH" "$HERE/vendor/cliui/run_tests.sh"
REXX_HOME="$RUNTIME_ROOT" REXX_BIN="$REXX_BIN" ./run_tests.sh

echo 'MINI_NOTES_DEV13_ENVIRONMENT_PASS'
