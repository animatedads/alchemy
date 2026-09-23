#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
"$REXX" "$ROOT/tests/test_core.rex"
"$REXX" "$ROOT/tests/test_guard_semantics.rex"
