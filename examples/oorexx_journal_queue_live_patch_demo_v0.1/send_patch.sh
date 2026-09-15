#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
if [[ -n "${OOREXX_BIN:-}" ]]; then
  export PATH="$OOREXX_BIN:$PATH"
  lib=$(cd "$OOREXX_BIN/../lib" 2>/dev/null && pwd || true)
  [[ -z "$lib" ]] || export LD_LIBRARY_PATH="$lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
command -v rexx >/dev/null 2>&1 || { echo "rexx not found; set OOREXX_BIN" >&2; exit 2; }
OOCLASS=$(dirname "$(command -v rexx)")
export REXX_PATH="$ROOT:$OOCLASS${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
exec rexx send_patch.rex "$@"
