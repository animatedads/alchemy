#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-${OOREXX_HOME:-/usr/local}/bin/rexx}"
MATHS_REXX="${MATHS_REXX:-}"
UNITS_REXX="${UNITS_REXX:-}"
OUT="${1:-$ROOT/out/f11_warbler_doppler}"
if [[ -z "$MATHS_REXX" || -z "$UNITS_REXX" ]]; then
  echo "Set MATHS_REXX and UNITS_REXX to Maths v0.9 and Units v0.1-dev4 rexx directories." >&2
  exit 2
fi
export REXX_PATH="$ROOT/rexx:$MATHS_REXX:$UNITS_REXX${REXX_PATH:+:$REXX_PATH}"
mkdir -p "$OUT"
exec "$REXX_BIN" "$ROOT/tests/f11_warbler_doppler_experiment.rex" "$OUT"
