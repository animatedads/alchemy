#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${MEMORY_FABRIC_DIR:?Expected exact Memory Fabric dev10 unpacked root}"
: "${SERVICE_DESCRIPTORS_DIR:?Expected Service Descriptors dev1 unpacked root}"
: "${REXX_BIN:?Expected exact qualified ooRexx binary}"
[[ -f "$MEMORY_FABRIC_DIR/src/MemoryFabric.cls" ]] || exit 2
[[ -f "$SERVICE_DESCRIPTORS_DIR/rexx/ServiceDescriptors.cls" ]] || exit 2
# The fixture is deliberately limited to this test; production requires the
# REAL dev34 XtpSocketProvider.cls and liboorexx_xtp_native.so.
export REXX_PATH="$ROOT/tests/fixtures:$ROOT/src:$MEMORY_FABRIC_DIR/src:$SERVICE_DESCRIPTORS_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
export MF_TEST_REGISTRY="${TMPDIR:-/tmp}/mf-protected-read-$$.tsv"
trap 'rm -f "$MF_TEST_REGISTRY" "$MF_TEST_REGISTRY.tmp"' EXIT
"$REXX_BIN" "$ROOT/tests/test_protected_read_bridge.rex"
