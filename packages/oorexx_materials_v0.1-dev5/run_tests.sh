#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$HERE/src:$HERE/deps/oorexx_units_v0.1-dev4/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_catalog.rex
rexx test_extension_catalog.rex

rexx test_rugby_materials.rex

rexx test_laser_materials.rex
