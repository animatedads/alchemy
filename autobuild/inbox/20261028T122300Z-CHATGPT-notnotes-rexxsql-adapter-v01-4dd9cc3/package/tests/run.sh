#!/bin/bash
set -euo pipefail
: "${REXX_HOME:?must supply ooRexx extracted usr/local}"
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
APP=${MININOTES_APP_ROOT:?must supply MiniNotes source path for NoSQL dependencies}
export LD_LIBRARY_PATH="$REXX_HOME/lib:$REXX_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT:$APP:$APP/src:$APP/vendor/nosql:$APP/vendor/notnotes:$APP/vendor/cliui/rexx:$APP/vendor/pdf/src:$APP/vendor/spreadsheet:$REXX_HOME/share/ooRexx:$REXX_HOME/bin"
"$REXX_HOME/bin/rexx" "$ROOT/tests/test_adapter_contract.rex"
