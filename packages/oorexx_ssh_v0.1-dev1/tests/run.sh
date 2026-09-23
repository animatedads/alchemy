#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX:=rexx}"
cd "$ROOT/tests"
"$REXX" test_registry.rex
"$REXX" test_authority.rex
"$REXX" test_foreign_libssh.rex ../bridge/libssh.bridge.json
"$REXX" test_version_gate.rex
