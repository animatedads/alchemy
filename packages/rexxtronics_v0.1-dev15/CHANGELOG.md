# Changelog

## 0.1-dev15

- Added `DCStampContext~stampVCCS` as an explicit MNA controlled-source primitive.
- Added polarity-symmetric compact `BipolarJunctionTransistor`, `NPNTransistor`, and `PNPTransistor` models with explicit CUTOFF / ACTIVE / SATURATED regions, signed base/collector/emitter currents, and power accounting.
- Saturation region selection compares requested beta-driven collector current with the finite saturation branch/load capacity, avoiding ACTIVE/SATURATED nonlinear iteration chatter.
- Added electrically solved common-cathode/common-anode `SevenSegmentDisplay` with seven protected LED branches, per-segment current/state, total power, and digit decoding from solved currents.
- Added source-backed Maxitronix 500-in-1 Project 14 PNP/NPN schematic fixtures and Project 15 transistor-switch/display fixture.
- Project 15 derives digit `8` from seven conducting electrical segment branches; the unknown historical built-in resistor value remains explicit qualification data rather than an invented part specification.
- Default and focused Physics integration suites remain passing.


## 0.1-dev14

- Rebased the optional Physics peer from the earlier fracture-only dev10 line to the exact user-supplied **Physics World v0.1-dev10.1** reconciliation archive (SHA-256 `936737a18d2c96a627e86d322b3dbf6bda06134a2410fc7eafb58c750cf6cc3c`), retaining both `FreeSurfaceFluids2D.cls` and `Fracture.cls` unchanged.
- Added `RexxTronicsFluids.cls` with `FreeSurfaceDepthObservation`, `PhysicsFreeSurfaceDepthProbe2D`, `LinearLiquidLevelTransducer`, `FreeSurfaceDepthSensorBinding`, and `FreeSurfaceElectricalCoupler2D`. Physics owns the liquid surface; Rexx-tronics owns only the explicit depth-to-voltage calibration and electrical network.
- Added a 2-D slosh -> two physical level probes -> two electrical voltage channels -> virtual oscilloscope qualification. A 0.6 m x 0.4 m tank driven diagonally for 90 ms resolves corner depths of about 0.1770717 m and 0.1254843 m, producing about 3.17679 V and 1.88711 V from the explicit 5–25 cm / 0–5 V qualification calibration.
- Uses the persistent transient stepper for the fluid/electrical partition, so capacitor/inductor history remains available and Physics/electrical endpoints share the same simulation time.
- Fixed a real high-precision MNA boundary leak: `DCStampContext` matrix/RHS accumulation now establishes 50-digit working precision, and resistor solved-current calculation does the same. A 3.1697464752475247524752475247524752475 V source now survives through the electrical solve and 1 kOhm branch-current calculation without collapsing to default method precision.
- Hardened the sine-source scope regression against exact-threshold endpoint sensitivity exposed by the precision repair by acquiring slightly beyond the second complete crossing rather than relying on a numerically exact final midline sample.
- Freshly passes the complete Rexx-tronics default suite and complete focused Physics peer-integration suite, including the new 2-D slosh/electrical test. `rexxc` passes all 16 Rexx-tronics and all 15 Physics dev10.1 source modules. The exact Physics manifest passes; all four fracture-authority fixtures and direct 2-D mass/forcing fixtures were also rerun successfully.
- Does not claim that a generic level sensor has the supplied linear calibration; exact part-number definitions must provide real transfer curves/limits. Nor does Rexx-tronics reproduce Physics hydrostatics/free-surface evolution.

## 0.1-dev13

- Rebases the pinned Physics peer from v0.1-dev9 to the exact user-supplied Physics World v0.1-dev10 archive (SHA-256 `7d3e0c1974a8f474b17a388132d45ee2e86199be6567a8711240efc8c1db92d4`) while retaining Maths v0.8 and Units v0.1-dev4 authorities.
- Adds `RexxTronicsFracture.cls` and `PhysicsFractureConductor`: one Physics `DeformableLink` can now be the physical authority behind an ordinary two-terminal electrical conductor.
- Keeps fracture causality in Physics. Rexx-tronics never applies an impact-damage heuristic; it opens the electrical path only after the exact linked Physics load path reports `broken`.
- Retains Physics `FractureEvent` evidence including simulation time, criterion, stress, released elastic energy and unresolved released energy at the electrical boundary.
- Adds `FractureElectricalCoupler`, which advances Physics deformation/contact first and the persistent electrical transient solver to the same partition endpoint, preserving the shared simulation-time contract.
- Adds direct tensile-fracture qualification: an energized 5 V / 1 kΩ path falls from about 4.99995 mA to ~5 pA when Physics breaks the conductor; post-fracture Physics topology contains two fragments.
- Adds contact -> compression -> fracture -> open-circuit qualification: the first 1 ms partition creates only the Physics contact impulse; the second 0.1 ms partition fractures by the configured `COMPRESSION` criterion at Physics time 1 ms, and the electrical solution at 1.1 ms loses load current.
- Explicitly does not claim arcing, air-gap breakdown, strain-dependent resistance, electrically/thermally driven fracture, electromigration or fracture-generated acoustics.
- Freshly passes the Rexx-tronics default suite, focused Physics integration suite, all four Physics dev10 fracture authority fixtures, and `rexxc` compilation of all 15 Rexx-tronics and all 14 Physics source modules.

## 0.1-dev12

- Rebases the optional Physics peer to the exact user-supplied Physics World v0.1-dev9 tree (archive SHA-256 `89b83dee9fda3566291ac41b4a097db1ce3afbc318c3daf47762b346b8c0e5bd`) while retaining Maths v0.8 and Units v0.1-dev4 as external authorities.
- Adds persistent `TransientSolver` operation through `begin`, `step`, `advance`, retained `lastSolution`, and accumulated `TransientResult`; dynamic component history is initialized once rather than per partition.
- Adds `Circuit~newTransientStepper(clock)` as the public history-preserving electrical co-simulation boundary while preserving the existing one-shot `simulateTransient` API.
- Adds `TransientElectromechanicalCoupler` and `TransientElectromechanicalCouplingStep`, interleaving a persistent backward-Euler electrical partition with Physics mechanics and reciprocal back EMF.
- Adds full R-L motor qualification: a 3 V source, 1 ohm winding resistance and 0.1 H winding inductance ramp current continuously rather than jumping to the DC value; reciprocal back EMF is retained across all partitions.
- Adds `RexxTronicsThermal.cls` using Physics dev9 `ThermalNode`/`ThermalPowerObservation`; electrical dissipation becomes heat only through an explicit `ElectricalDissipationThermalBridge`. Negative electrical power is never silently reclassified as heat.
- Adds an end-to-end electrical loudspeaker fixture using the real winding R/L plus reciprocal voice-coil mechanics, Physics dev9 `RigidRadiatingPatch`/`ContinuousMechanicalAcousticRenderer`, a Rexx-tronics microphone, and the virtual oscilloscope. Pressure is generated from resolved diaphragm motion, not from an electrical-current-to-pressure shortcut.
- Adds `FeedbackLinearRegulator`, a finite VIN->VOUT pass path with explicit three-pole control-loop state. It is not an ideal voltage clamp and it does not inspect the circuit for a capacitor or hard-code a no-Cout failure.
- Adds the missing-output-capacitor qualification. For one explicit high-loop-gain test profile, a 100 ohm -> 50 ohm load step produces 7.592 Vpp late oscillation with `Cout=0`; adding a real 100 uF electrical capacitor reduces late ripple to about 0.000742 Vpp and settles near 4.941 V. A lower-gain control profile remains stable with `Cout=0`, proving instability is model-derived rather than triggered by capacitor absence.
- Adds the regulator/capacitor experiment as an ordinary electrical transient and oscilloscope fixture; exact regulator part-number definitions are expected to supply loop poles/gain/output-stage parameters from datasheet evidence.
- Retains the dev11 quasi-static electromechanical coupler for memoryless/DC use; dev12 does not mislabel the persistent staggered coupler as a fully implicit iterative multi-domain solve.

## 0.1-dev11

- Rebased the optional Physics peer from v0.1-dev6 to the user-supplied Physics World v0.1-dev8, preserving Maths v0.8 and Units v0.1-dev4 authorities.
- Added `RexxTronicsElectromechanics.cls` and a reciprocal Physics back-EMF electrical source.
- Added typed electrical-drive bridging into Physics dev8 linear and rotary electromechanical transducers.
- Added an explicit quasi-static staggered electrical/mechanical coupling step: solve current/back-EMF state, apply force/torque, advance mechanics, then re-solve with new back EMF.
- Kept winding resistance and electrical loss in Rexx-tronics rather than hiding them inside Physics; preserved Physics conversion/mechanical power evidence.
- Added linear voice-coil-style and rotary motor feedback qualifications. The rotary fixture falls from 3 A at rest to 2.851875 A after 200 ms as 0.148125 V reciprocal back EMF develops.
- Explicitly did not claim coupled winding-inductance history in the quasi-static stepper; full R-L electromechanical co-simulation required a persistent transient stepper.
- Pinned Physics dev8 unchanged at SHA-256 `08f6a7c40b27c8b0612df7e5e8ec5def8369725a0379e4aaec9aea5610121c07`.

## 0.1-dev10

- rebased the pinned shared unit authority to unmodified ooRexx Units v0.1-dev4;
- rebased the optional Physics peer to unmodified ooRexx Physics World v0.1-dev6;
- added `RexxTronicsAcoustics.cls`;
- added `LinearMicrophoneTransducer`, a deliberately explicit ideal flat pressure-to-voltage qualification model with typed V/Pa sensitivity, DC bias, optional output rails, and LINEAR/HOLD interpolation over Physics pressure samples;
- made the microphone a real two-terminal electrical component that can stamp a time-varying voltage source into transient MNA;
- added Physics -> microphone -> virtual oscilloscope qualification at exactly 136 dB SPL (pressure specified at the microphone);
- added 1 kg finite-contact box impact -> structural mode -> acoustic pressure -> electrical microphone -> scope qualification using Physics dev6 ContactDynamics and MechanicalAcoustics;
- added a combined block-impact + 136 dB / 1 kHz acoustic-pressure -> microphone -> oscilloscope regression;
- retained simulation-time authority: Physics sample time is projected to the existing integer-picosecond timeline and wall-clock time does not affect the acquired waveform.

## 0.1-dev7

- Rebased the pinned, unmodified shared Units dependency to user-supplied `oorexx_units_v0.1-dev3`.
- Qualified dev3 engineering scales numerically, including micro/milli/kilo electrical units and GHz plus Unicode micro input aliases supported by Units.
- Kept upstream Units dev3 packaging/version observations documented rather than forking the dependency.
- Added `LightResistancePoint` and `LightResistanceCurve` for explicit, datasheet-driven illuminance-to-resistance characteristics with fail-closed extrapolation by default.
- Added `IlluminanceObservation` carrying physical input, simulation time, source and causal provenance.
- Added `PhotoResistor`, converting Physics/environment observations into ordinary electrical resistance and supporting scheduled illuminance changes on `SimulationClock`.
- Added DC and transient qualification proving the same photoresistor circuit changes from 2.5 V at 100 lx to 0.454545... V at 1000 lx at an exact scheduled 2 ms simulation-time boundary.
- Fixed the stale `RexxTronicsBuild~RELEASE` constant to `0.1-dev7`.
- Retained all dev6 nonlinear semiconductor, kit-project, timing, aliasing, RLC, switching and Units qualifications.

## 0.1-dev6

- Added bounded nonlinear operating-region iteration to both DC and transient MNA solves.
- Added `Diode` with deterministic OFF/FORWARD piecewise-linear behaviour and observable current, power, voltage drop and state.
- Added optional reverse-breakdown region and `ZenerDiode` convenience type.
- Added `LED` electrical model with explicit light-current threshold plus optional radiant-efficiency and wavelength metadata for the Physics boundary; unspecified optical efficiency remains unknown rather than invented.
- Ensured transient nonlinear trials do not advance capacitor/inductor history until the timestep has converged.
- Added forward/reverse diode, zener-breakdown and nonlinear LED transient qualification.
- Added `RexxTronicsKits.cls` and the first source-backed project fixture: Maxitronix 500-in-1 Hardware Entry Course Project 7, LIGHT TELEGRAPH (3 V source, 270 ohm resistor, LED and S1 key).
- Added executable Project 7 example and closed/open-key behaviour qualification.
- Retained all dev5 Units, timing, aliasing, topology, DC, controls, RC and RL qualification.

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


## 0.1-dev8

- pinned the user-supplied ooRexx Physics World v0.1-dev4 as an optional, unmodified peer snapshot;
- added `RexxTronicsPhysical.cls` with data-driven electrical-power -> luminous-intensity transfer and `PhotometricLamp`;
- added `RexxTronicsPhysics.cls` implementing the concrete Physics `OpticalBeamProbe` -> typed illuminance observation boundary;
- Physics sampling scheduled for a future simulation instant occurs at event execution time, so changed world geometry is observed rather than precomputed;
- added retained physical provenance/evidence to `IlluminanceObservation` and `PhotoResistor`;
- added ordinary qualification for the electrical->photometric transducer and provenance retention;
- added optional end-to-end Physics optical round-trip qualification;
- documented the current central-ray + exact rectangular-photometry scope without claiming full aperture/spectral integration.

## 0.1-dev9

- Pins the user-supplied ooRexx Maths v0.8 tree unchanged under `deps/` for reproducible Physics qualification.
- `run_physics_tests.sh` is now self-contained by default; `REXXTRONICS_MATHS_ROOT` / `MATHS_REXX` can still override the pinned qualification copy.
- Executes the previously pending real Physics World optical round-trip against Maths v0.8.
- Adds scheduled Physics sampling qualification: geometry may change earlier on the same `SimulationClock`, and the optical observation is sampled at the scheduled instant rather than precomputed at schedule time.
- Adds `run_peer_optics_tests.sh` for focused Maths 3-D + Physics optical peer qualification without conflating the Rexx-tronics adapter test with the full Physics mechanics/acoustics suite.
- Repairs a scheduler defect exposed by the new peer test: `Array~remove()` left sparse indexes, so a second queued event could be skipped/nil-dereferenced. `SimulationClock` now compacts its queue deterministically after dispatch and retains sequence ordering for equal timestamps.
- Adds a three-event scheduler regression covering out-of-order insertion and equal-time ordering.