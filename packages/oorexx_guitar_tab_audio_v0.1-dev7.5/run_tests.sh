#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_BIN:=rexx}"
: "${PHYSICS_ROOT:?set PHYSICS_ROOT to current Physics World root}"
: "${MATHS_ROOT:?set MATHS_ROOT to current Maths root}"
: "${UNITS_ROOT:?set UNITS_ROOT to Units root}"

export REXX_PATH="$ROOT/src:$PHYSICS_ROOT/rexx:$MATHS_ROOT/rexx:$UNITS_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"

"$OOREXX_BIN" "$ROOT/tests/test_tab_parser.rex"
"$OOREXX_BIN" "$ROOT/tests/test_midi_reader_synthetic.rex"
"$OOREXX_BIN" "$ROOT/tests/test_bass_string_consistency.rex"
"$OOREXX_BIN" "$ROOT/tests/test_current_peer_contracts.rex"

if [[ "${GUITAR_RUN_ELECTRICAL:-0}" == 1 ]]; then
  : "${REXXTRONICS_ROOT:?GUITAR_RUN_ELECTRICAL=1 requires accepted REXXTRONICS_ROOT}"
  export REXX_PATH="$REXXTRONICS_ROOT/src:$REXX_PATH"
  "$ROOT/tests/check_rexxtronics_peer.sh"
fi

if [[ "${GUITAR_RUN_EXPENSIVE:-0}" == 1 ]]; then
  if [[ "${GUITAR_RUN_ELECTRICAL:-0}" != 1 ]]; then
    echo "FAIL expensive full render requires GUITAR_RUN_ELECTRICAL=1" >&2
    exit 44
  fi
  "$OOREXX_BIN" "$ROOT/tests/test_render.rex"
  "$OOREXX_BIN" "$ROOT/tests/test_telemetry_routing.rex"
fi
