#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
"${REXX_BIN:-rexx}" "$root/tests/test_cartography_intake.rex"
