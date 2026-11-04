#!/bin/sh
# Native ooRexx runner, requires ooRexx 5.3 and rxmath in the installed runtime.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
rexx=${REXX_BIN:-rexx}
"$rexx" "$root/tests/test_opera_west_walk.rex"
"$rexx" "$root/bin/render_opera_west_walk.rex" "$root/opera_west_walk_360.svg"