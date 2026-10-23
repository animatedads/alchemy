#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${MEMORY_FABRIC_DIR:?}" "${SERVICE_DESCRIPTORS_DIR:?}" "${XTP_DIR:?}" "${OPERATIONAL_PLANNER_DIR:?}" "${SOCKET_PROVIDER_DIR:?}"
: "${REXX_BIN:=rexx}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export MF_OPCTL="$OPERATIONAL_PLANNER_DIR/bin/opctl"
export OPERATIONAL_POLICY_FILE="$TMP/class.tsv"
export OPERATIONAL_CAPACITY_FILE="$TMP/cap.tsv"
export MF_TEST_REGISTRY="$TMP/services.tsv"
export REXX_PATH="$ROOT/src:$MEMORY_FABRIC_DIR/src:$SERVICE_DESCRIPTORS_DIR/rexx:$XTP_DIR/rexx:$SOCKET_PROVIDER_DIR/src:$OPERATIONAL_PLANNER_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
"$MF_OPCTL" class add normal.memory --normal allow:100:allow:any:30:2:60 --degraded throttle:75:allow:any:25:2:50 --constrained throttle:50:forbid:protected:15:1:15 --emergency suspend:0:forbid:protected:10:1:10
"$REXX_BIN" "$ROOT/tests/test_capacity_admission.rex"
