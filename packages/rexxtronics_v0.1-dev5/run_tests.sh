#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# ooRexx Units is a separate shared authority.  A byte-for-byte dependency
# snapshot is pinned under deps for reproducible qualification; consumers may
# override it with REXXTRONICS_UNITS_ROOT.
UNITS_ROOT=${REXXTRONICS_UNITS_ROOT:-"$HERE/deps/oorexx_units_v0.1-dev2"}
if [ ! -f "$UNITS_ROOT/rexx/Units.cls" ]; then
  echo "Rexx-tronics: Units.cls not found under $UNITS_ROOT/rexx" >&2
  exit 2
fi

export REXX_PATH="$HERE/src:$UNITS_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_simulation_time.rex
rexx test_aliasing.rex
rexx test_topology_path.rex
rexx test_dc_voltage_divider.rex
rexx test_dc_current_source.rex
rexx test_variable_resistor.rex
rexx test_potentiometer.rex
rexx test_switch.rex
rexx test_rc_transient.rex
rexx test_scheduled_switch_transient.rex
rexx test_units_integration.rex
rexx test_units_dev2_contract.rex
rexx test_inductor_transient.rex
