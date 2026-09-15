#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$HERE/src:$HERE/runtime:$HERE/tests${REXX_PATH:+:$REXX_PATH}"
for t in "$HERE"/tests/test_*.rex; do rexx "$t"; done
