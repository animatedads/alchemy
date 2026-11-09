#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
"$REXX_BIN" test_geometry.rex
"$REXX_BIN" test_guards.rex