#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$HERE${REXX_PATH:+:$REXX_PATH}"
REXX="${REXX_BIN:-rexx}"
cd "$HERE"
"$REXX" test_other_cameras.rex
"$REXX" fit_other_cameras.rex