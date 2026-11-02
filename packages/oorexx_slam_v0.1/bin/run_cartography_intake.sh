#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$here${REXX_PATH:+:$REXX_PATH}"
"${REXX_BIN:-rexx}" "$here/test_cartography_intake.rex"