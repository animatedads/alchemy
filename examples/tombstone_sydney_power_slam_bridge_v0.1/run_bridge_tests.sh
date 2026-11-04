#!/bin/sh
set -eu
: "${OO_ROOT:?set OO_ROOT to extracted ooRexx root}"
export PATH="$OO_ROOT/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="$OO_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$(dirname "$0"):${POWER_SLAM_LIB:?set POWER_SLAM_LIB to v0.8 classes}${REXX_PATH:+:$REXX_PATH}"
cd "$(dirname "$0")"
rexx test_power_slam_v5v_bridge.rex observations.psv
