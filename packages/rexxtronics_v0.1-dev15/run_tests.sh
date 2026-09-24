#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# ooRexx Units is a separate shared authority.  A byte-for-byte dependency
# snapshot is pinned under deps for reproducible qualification; consumers may
# override it with REXXTRONICS_UNITS_ROOT.
UNITS_ROOT=${REXXTRONICS_UNITS_ROOT:-"$HERE/deps/oorexx_units_v0.1-dev4"}
if [ ! -f "$UNITS_ROOT/rexx/Units.cls" ]; then
  echo "Rexx-tronics: Units.cls not found under $UNITS_ROOT/rexx" >&2
  exit 2
fi

export REXX_PATH="$HERE/src:$UNITS_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_simulation_time.rex
rexx test_event_queue_multiple.rex
rexx test_aliasing.rex
rexx test_topology_path.rex
rexx test_dc_voltage_divider.rex
rexx test_dc_current_source.rex
rexx test_sine_voltage_source.rex
rexx test_variable_resistor.rex
rexx test_potentiometer.rex
rexx test_switch.rex
rexx test_rc_transient.rex
rexx test_scheduled_switch_transient.rex
rexx test_units_integration.rex
rexx test_solver_precision_boundary.rex
rexx test_units_dev2_contract.rex
rexx test_units_dev3_contract.rex
rexx test_units_dev4_contract.rex
rexx test_inductor_transient.rex
rexx test_persistent_transient_stepper.rex
rexx test_regulator_output_cap_stability.rex
rexx test_diode_pwl.rex
rexx test_zener_breakdown.rex
rexx test_led_transient.rex
rexx test_bjt_pwl.rex
rexx test_seven_segment_display.rex
rexx test_maxitronix500_project007.rex
rexx test_maxitronix500_project014.rex
rexx test_maxitronix500_project015.rex
rexx test_photoresistor_physics_boundary.rex
rexx test_photometric_lamp.rex
rexx test_physical_provenance.rex
