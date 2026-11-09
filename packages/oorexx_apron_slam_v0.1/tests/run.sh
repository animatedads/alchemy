#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
"$REXX_BIN" test_geometry.rex
"$REXX_BIN" test_guards.rex
"$REXX_BIN" test_transient_motion.rex
"$REXX_BIN" test_motion_rejections.rex
"$REXX_BIN" test_road3d.rex
"$REXX_BIN" test_road_guards.rex
