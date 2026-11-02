#!/bin/sh
set -eu
raw=${1:-harbour_heights.words}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REXX_PATH="$here${REXX_PATH:+:$REXX_PATH}"; export REXX_PATH
sh "$here/qualify_harbour_words.sh" "$raw"
rexx "$here/test_grid_parity.rex" "$raw" "$here/grid_sample_120.psv"
echo 'HARBOUR_TERRAIN_V036_ALL_NATIVE_QUALIFICATIONS_PASS'
