#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${REXX:=rexx}"
: "${STORAGE_FABRIC_ROOT:=../../storage}"
"$REXX" test_core.rex
REXX_PATH="../src:${STORAGE_FABRIC_ROOT}${REXX_PATH:+:$REXX_PATH}" "$REXX" test_fuse.rex
