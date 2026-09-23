# Changelog

## 0.1-dev5

- Rebased the shared quantity authority from `oorexx_units_v0.1-dev1` to user-supplied `oorexx_units_v0.1-dev2` without forking it.
- Confirmed Units dev2 closes the high-precision scalar leakage observed during dev4 integration; 50-digit quantity construction now survives the Units boundary unchanged.
- Added Rexx-tronics acceptance of parseable textual quantities at typed electrical boundaries, for example `4.7 kΩ`, `250 mV`, `220 nF`, `10 mH`, `5 V` and `2 ms` where the shared Units parser recognizes the unit token.
- Added validated quantity reconstruction from the Units `oorexx.units.quantity/0.1` metadata schema for persistence and Physics/cross-library exchange.
- Added ideal `Inductor` with quantity-valued inductance/current/power/stored-energy observations.
- Added DC ideal-short inductor stamping with observable branch current.
- Added backward-Euler transient inductor companion model with explicit initial current and retained current state.
- Added RL step-response qualification and example using typed/textual Units inputs.
- Retained every dev4 timing, aliasing, topology, DC, controls, RC transient and mixed-unit qualification.

## 0.1-dev4

- Adopted `oorexx_units_v0.1-dev1` as the shared Units/Quantity authority.
- Added `RexxTronicsUnits` boundary adapter; dimensional validation occurs before canonical numeric values enter the solver.
- Added UnitQuantity input support for voltage/current sources, resistors, variable resistors, potentiometers, switches, capacitors, oscillator frequency/levels, simulation time and oscilloscope acquisition.
- Added quantity-valued DC/transient result accessors and quantity-valued component/instrument observations.
- Added direct time-quantity projection to the integer-picosecond simulation timeline with fail-closed sub-picosecond handling.
- Added mixed-unit qualification covering mV/V, kohm/Mohm, mA/A, uF/F, kHz/Hz, ms/us and percent/dimensionless values.
- Added fail-closed regression proving that a voltage quantity cannot be supplied as a resistance.
- Pinned an unmodified Units v0.1-dev1 qualification snapshot under `deps/`, while preserving Units as a separate shared authority.
- Documented an upstream Units v0.1-dev1 scalar-precision observation rather than locally forking the shared dependency.
- Retained all dev3 timing, aliasing, topology, DC, control and transient qualifications.

## 0.1-dev3

- Added fixed-step transient solver using the existing MNA topology.
- Added backward-Euler capacitor companion model and explicit capacitor initial voltage.
- Added `StepVoltageSource` for deterministic transient excitation.
- Added `VariableResistor` with normalized 0..1 position and bounded resistance.
- Added three-terminal `Potentiometer` with normalized wiper position.
- Added open/closed `Switch` with both solver and topology semantics.
- Added `TransientResult`, time-indexed solution points, voltage/current interpolation, and signal projection.
- Extended `VirtualOscilloscope` with generic `acquireSignal()` so transient and event-driven signals share one simulation-time instrument model.
- Integrated transient stepping with `SimulationClock`, allowing scheduled component events to affect subsequent electrical solutions.
- Documented the Physics-library boundary: non-electrical propagation stays outside Rexx-tronics; exchanged quantities must preserve simulation time and causal provenance.
- Retained all dev2 DC/topology and dev1 timing/aliasing qualifications.
