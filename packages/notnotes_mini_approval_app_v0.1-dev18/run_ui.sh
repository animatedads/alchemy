#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${REXX_HOME:=/usr/local}"
REXX_BIN=${REXX_BIN:-$REXX_HOME/bin/rexx}
if [ ! -x "$REXX_BIN" ]; then REXX_BIN=$(command -v rexx); fi
if [ ! -f "$HERE/vendor/cliui/lib/libcliui_oorexx.so" ]; then
  REXX_HOME="$REXX_HOME" "$HERE/build_cliui.sh"
fi
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$HERE/vendor/cliui/lib:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$HERE/vendor/cliui/lib:$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE"
exec "$REXX_BIN" examples/mini_notes_ui.rex
