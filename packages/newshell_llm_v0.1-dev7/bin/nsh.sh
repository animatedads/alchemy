#!/usr/bin/env bash
# nsh.sh - start the NewShell console. Run tests/run_tests.sh once first: it
# builds the process runner's native library and writes build/env.sh.
# Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/build/env.sh" ] || { echo "run WRITE_ENV=1 tests/run_tests.sh first (it writes build/env.sh)"; exit 2; }
. "$ROOT/build/env.sh"
exec "$REXX_BIN" "$ROOT/bin/nsh.rex" "$@"
