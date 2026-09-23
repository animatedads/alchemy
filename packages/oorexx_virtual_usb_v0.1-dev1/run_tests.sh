#!/bin/sh
set -eu
: "${REXX:=rexx}"
"$REXX" tests/test_core.rex
"$REXX" tests/test_chapter9.rex
"$REXX" tests/test_raw_gadget_bridge.rex
