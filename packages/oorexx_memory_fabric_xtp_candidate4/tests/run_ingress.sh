#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${MEMORY_FABRIC_DIR:?Point to Memory Fabric dev10 root}"
: "${SERVICE_DESCRIPTORS_DIR:?Point to Service Descriptors dev1 root}"
: "${REXX_BIN:?Point to qualified ooRexx binary}"
[[ -f "$MEMORY_FABRIC_DIR/src/MemoryFabric.cls" ]] || { echo 'Missing MemoryFabric.cls' >&2; exit 2; }
[[ -f "$SERVICE_DESCRIPTORS_DIR/rexx/ServiceDescriptors.cls" ]] || { echo 'Missing ServiceDescriptors.cls' >&2; exit 2; }
export REXX_PATH="$ROOT/src:$MEMORY_FABRIC_DIR/src:$SERVICE_DESCRIPTORS_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
export MF_TEST_REGISTRY="${TMPDIR:-/tmp}/memory-xtp-ingress-$$.tsv"
trap 'rm -f "$MF_TEST_REGISTRY" "$MF_TEST_REGISTRY.tmp"' EXIT
"$REXX_BIN" "$ROOT/tests/test_read_ingress.rex"
