#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
REXX_BIN=${REXX_BIN:-rexx}
: "${REXX_HOME:=/usr/local}"
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$REXX_BIN" examples/mini_notes.rex
