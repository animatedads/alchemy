#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
export REXX_PATH="$PWD/tests/stubs:$PWD/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" tests/smoke.rex "$@"
"$REXX_BIN" tests/layers.rex
"$REXX_BIN" tests/continuity.rex
