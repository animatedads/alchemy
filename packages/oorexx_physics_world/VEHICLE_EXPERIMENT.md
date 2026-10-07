# F11 moving-vehicle acoustic experiment

This development package adds reusable ooRexx Physics primitives for a moving acoustic source and a finite 4 m x 1.5 m moving reflective side panel, plus the F11 experiment runner.

Authoritative vertical facts used here:

- road z = 0.0 m
- property floor z = 3.0 m
- floor-to-ceiling height = 2.2 m
- ceiling z = 5.2 m
- FC and FD z = 4.8 m
- stationary internal test source z = 4.8 m
- vehicle acoustic source z = 0.5 m
- vehicle height = 1.5 m
- vehicle length = 4.0 m
- vehicle speed = 40 km/h = 11.111111111... m/s

Vehicle source is 78 dB SPL total @ 1 m, split by acoustic power into 125 Hz / 30%, 1000 Hz / 60%, and 4000 Hz / 10%. Component levels are derived logarithmically and recombine to 78 dB.

The experiment writes both aggregate receiver rows and every admitted path. It executes five requested families:

1. no stationary noise + vehicle RTL
2. no stationary noise + vehicle LTR
3. stationary noise at each grid location + no vehicle
4. stationary noise at each grid location + vehicle RTL
5. stationary noise at each grid location + vehicle LTR

Each vehicle-present family uses five snapshots plus the no-car control supplied by family 3. `f11_vehicle_summary.csv` reports FC/FD band levels, total level, first arrival and Doppler-shifted vehicle bands. `f11_vehicle_paths.csv` retains direct/transmitted/reflected path evidence.

The supplied plan remains the X/Y authority. `geometry/f11_f12_proportion_geometry_v0.3.json` carries the authoritative vertical/vehicle facts and preserves the 9.43 m FC-FD calibration.

Interior wall panels now span the authoritative property interval z=3.0..5.2 m. FC, FD and internal test sources remain at z=4.8 m: 1.8 m above the floor and 0.4 m below the ceiling. The ceiling plane height is authoritative, but no ceiling acoustic material is invented; ceiling reflections remain disabled until a ceiling construction/material is specified.

Run:

    MATHS_REXX=/path/oorexx_maths_v0.9/rexx \
    UNITS_REXX=/path/oorexx_units_v0.1-dev4/rexx \
    ./run_f11_vehicle_experiment.sh out/f11

Optional bounded development run:

    F11_GRID_MAX_X=3 F11_GRID_MAX_Y=3 F11_CAR_STATES=2 ...

The full grid is intentionally computationally substantial because each state solves finite-surface first-order reflection paths rather than using a TDOA shortcut.
