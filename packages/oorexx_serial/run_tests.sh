#!/bin/sh
set -eu
: "${REXX:=rexx}"
"$REXX" tests/test_core.rex
"$REXX" tests/test_framing.rex
"$REXX" tests/test_events.rex
"$REXX" tests/test_posix_pty.rex
"$REXX" examples/sensor_lines.rex
