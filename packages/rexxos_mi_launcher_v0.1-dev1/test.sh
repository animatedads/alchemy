#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${NEWSHELL_HOME:?set NEWSHELL_HOME}"
: "${NATIVE_HOME:?set NATIVE_HOME to built dev18}"
export REXX_PATH="$PWD/src:$NATIVE_HOME/src:$NEWSHELL_HOME/src:${REXX_PATH:-}"
export LD_LIBRARY_PATH="$NATIVE_HOME/lib:$NEWSHELL_HOME/lib:${LD_LIBRARY_PATH:-}"
sh -n bin/mi-namespace-exec bin/stage-image.sh
rexx tests/test.rex
