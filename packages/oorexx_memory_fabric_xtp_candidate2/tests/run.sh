#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:=rexx}"
: "${MEMORY_FABRIC_DIR:?Set MEMORY_FABRIC_DIR to Memory Fabric dev10 source root}"
: "${SERVICE_DESCRIPTORS_DIR:?Set SERVICE_DESCRIPTORS_DIR to Service Descriptors source root}"
: "${XTP_DIR:?Set XTP_DIR to XTP source root}"
: "${SOCKET_PROVIDER_DIR:?Set SOCKET_PROVIDER_DIR to Socket Provider source root}"
: "${OPERATIONAL_PLANNER_DIR:?Set OPERATIONAL_PLANNER_DIR to Operational Planner dev2 root}"
export OPERATIONAL_POLICY_FILE="${TMPDIR:-/tmp}/memory-xtp-operational-$$.tsv"
export MF_OPCTL="$OPERATIONAL_PLANNER_DIR/bin/opctl"
export MF_TEST_REGISTRY="${TMPDIR:-/tmp}/memory-xtp-services-$$.tsv"
trap 'rm -f "$MF_TEST_REGISTRY" "$MF_TEST_REGISTRY.tmp" "$OPERATIONAL_POLICY_FILE"' EXIT
export REXX_PATH="$ROOT/src:$MEMORY_FABRIC_DIR/src:$SERVICE_DESCRIPTORS_DIR/rexx:$XTP_DIR/rexx:$SOCKET_PROVIDER_DIR/src:$OPERATIONAL_PLANNER_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_memory_xtp_planning.rex"
"$MF_OPCTL" class add normal.memory \
  --normal allow:100:allow:any:30:2:60 \
  --degraded throttle:75:allow:any:25:2:50 \
  --constrained throttle:50:forbid:protected:15:1:15 \
  --emergency suspend:0:forbid:protected:10:1:10 >/dev/null
"$MF_OPCTL" class add memory.critical \
  --normal allow:100:allow:protected:40:2:80 \
  --degraded allow:100:allow:protected:40:2:80 \
  --constrained allow:100:forbid:protected:40:2:80 \
  --emergency allow:100:forbid:protected:40:2:80 >/dev/null
"$REXX_BIN" "$ROOT/tests/test_real_policy.rex"
