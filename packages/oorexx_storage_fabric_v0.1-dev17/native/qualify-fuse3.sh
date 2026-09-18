#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/native/probe-fuse3.sh" "$ROOT/build/storage-fuse3"
"$ROOT/native/test-fuse3-syntax.sh"
"$ROOT/native/test-fuse3-self-probe-stub.sh"
"$ROOT/native/test-protocol.sh"
REXX_BIN=${REXX_BIN:-rexx}
"$REXX_BIN" "$ROOT/tests/test_fuse_rpc_dispatcher.rex"
echo 'PASS storage-fuse3 pre-COMMIT qualification'