#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_BIN:=rexx}"
: "${PHYSICS_ROOT:?set PHYSICS_ROOT to Physics World package root}"
: "${REXXTRONICS_ROOT:?set REXXTRONICS_ROOT to Rexx-tronics package root}"
: "${MATHS_ROOT:?set MATHS_ROOT to Maths v0.10 package root}"
: "${UNITS_ROOT:?set UNITS_ROOT to Units package root}"
export REXX_PATH="$ROOT/src:$PHYSICS_ROOT/rexx:$REXXTRONICS_ROOT/src:$MATHS_ROOT/rexx:$UNITS_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_BIN" "$ROOT/tests/test_tab_parser.rex"
"$OOREXX_BIN" "$ROOT/tests/test_maths_modal_equivalence.rex"
"$OOREXX_BIN" "$ROOT/tests/test_midi_reader_synthetic.rex"

if [[ "${GUITAR_RUN_EXPENSIVE:-0}" == 1 ]]; then
  "$OOREXX_BIN" "$ROOT/tests/test_render.rex"
  "$OOREXX_BIN" "$ROOT/tests/test_telemetry_routing.rex"
fi

if [[ "${GUITAR_RUN_NUMPY:-0}" == 1 ]]; then
  : "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to directory containing python_foreign.cls}"
  export REXX_PATH="$FOREIGN_RUNTIME_ROOT:$REXX_PATH"
  "$OOREXX_BIN" "$ROOT/examples/demo_rock_noise_pollution_intro_native.rex"     "$ROOT/examples/rock_noise_pollution_dev5_numpy.wav"     "$ROOT/examples/rock_noise_pollution_dev5_numpy_gauges.csv"
fi

if [[ -n "${GUITAR_MIDI_TE_DEUM:-}" ]]; then
  "$OOREXX_BIN" "$ROOT/tests/test_midi_reader.rex" "$GUITAR_MIDI_TE_DEUM" "${GUITAR_MIDI_QUEEN:-}"
fi
