#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
REXX_BIN=${REXX_BIN:-rexx}
: "${REXX_HOME:=/usr/local}"
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
# Consume neighbouring source providers; never vendor an alternative SQL driver.
REXXSQL_SRC="$HERE/../oorexx_rexxsql_backend_v0.1/src"
NATIVE_DB_SRC="$HERE/../oorexx_native_database_backends_v0.1/src"
if [[ -d "$REXXSQL_SRC" && -d "$NATIVE_DB_SRC" ]]; then
  export REXX_PATH="$REXXSQL_SRC:$NATIVE_DB_SRC:$REXX_PATH"
fi
export LD_LIBRARY_PATH="${REXXSQL_LIB_DIR:+$REXXSQL_LIB_DIR:}$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
SCRIPT=${1:-examples/codex_walkthrough.txt}
exec "$REXX_BIN" examples/run_scripted.rex "$SCRIPT"
