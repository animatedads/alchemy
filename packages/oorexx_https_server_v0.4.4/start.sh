#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OOREXX="${OOREXX:-}"
if [[ -z "$OOREXX" ]]; then
  if command -v rexx >/dev/null 2>&1; then
    REXX_BIN="$(command -v rexx)"
    OOREXX="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
  else
    echo "ooRexx not found; set OOREXX to the ooRexx installation prefix" >&2
    exit 2
  fi
fi
REXX="$OOREXX/bin/rexx"
[[ -x "$REXX" ]] || { echo "missing $REXX" >&2; exit 2; }
LIBDIR="$OOREXX/lib"
[[ -d "$OOREXX/lib64" ]] && LIBDIR="$OOREXX/lib64"
export LD_LIBRARY_PATH="$ROOT/vendor/foreign_runtime_v0.17.1/build:$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/foreign_runtime_v0.17.1/rexx:$OOREXX/bin${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$ROOT/bin/https_server.rex" "$*"
