#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/tests/test_projection_shell.sh"
"$ROOT/tests/test_preview_boundary.sh"
node --test "$ROOT/tests/test_compiled_release.mjs"
"$ROOT/tests/test_starter.sh"
echo 'VECTOR MERIDIAN MARKETS WIRE UI WEB v0.2: PASS'
