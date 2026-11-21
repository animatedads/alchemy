#!/bin/sh
set -eu
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$HERE/tests"
RUNNER=${REXX:-rexx}
"$RUNNER" test_sydney_camera_coarse_fix.rex
"$RUNNER" test_recovery_envelope.rex