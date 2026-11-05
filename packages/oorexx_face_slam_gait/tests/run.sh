#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?Set REXX_BIN to the tested ooRexx executable}"
: "${REXX_LIB_DIR:?Set REXX_LIB_DIR to the matching ooRexx library directory}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$REXX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/tests/test_gait_contract.rex"
"$REXX_BIN" "$ROOT/tests/test_temporal.rex"
"$REXX_BIN" "$ROOT/tests/test_pose_packet.rex"
