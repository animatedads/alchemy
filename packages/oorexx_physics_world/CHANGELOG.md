# v0.1-dev46.6
- Rebases accelerated guitar dynamics on ooRexx Maths v0.14 causal block continuation.
- Adds `GuitarMathsDynamicsProjection~continuation()` and `~continuationFromCurrentState()`.
- Adds `~advanceContinuationBlock()` so each block writes the terminal Maths state back into the authoritative Physics oscillator/body objects and journals Maths evidence.
- Replaces residual RxMath pi construction in the guitar M/C/K projection with `.Maths~pi(context)`.
- Adds `test_guitar_maths14_continuation.rex`: twelve native continuation blocks versus one monolithic native solve, plus sample-delay snapshot/restore.

# v0.1-dev46.1

- Repairs `DrumKitPhysics` bounded acoustic history by using a compact FIFO `Queue`; repeated pruning no longer leaves `.nil` at index 1.
- Caches invariant drum modal `omega`, stiffness and damping coefficient, and caches current acceleration for pressure/history observation.
- Adds reciprocal weak structural links between representative kick/snare/tom/cymbal support modes so a single strike can sympathetically energize connected kit members without one-way energy injection.
- Includes structural-link spring energy in the drum-kit mechanical energy budget.
- Corrects drum regression timesteps to remain stable for the highest dev46 cymbal mode under symplectic Euler.
- Adds explicit history-pruning and single-strike sympathetic-energy regressions.

# v0.1-dev46

- Adds independent full physical drum-kit peer class (`DrumKitPhysics.cls`) with kick/snare/toms/hi-hat/crashes/ride, acoustic sympathetic excitation, retarded pressure history and PhysicalWorld freeze/restore participation.

# Changelog

## 0.1-dev17

- Adds `BallisticFlight.cls` with deterministic aerodynamic rigid-body flight experiments.
- Adds `RugbyBallFlightFactory`, consuming Parts-style mass/length/circumference projections and constructing a prolate-body reference inertia.
- Couples dev16 aerodynamic force/torque into Mechanics integration so gravity, drag, spin torque and changing orientation evolve together.
- Adds time-stamped flight-state observations and bounded run/run-until-ground experiment APIs.


## 0.1-dev16

- Adds `RigidBodyAerodynamics.cls`: orientation-sensitive drag, wind-relative velocity, explicit spin-lift and spin-damping extension coefficients, aerodynamic force/torque observations, and a Sports Ball projection adapter.
- Consumes Parts-style rugby-ball length/circumference projection without importing Parts or inventing rugby-specific aerodynamic coefficients.
- Qualifies broadside drag, zero-relative-air behavior, rugby projected area and spin-lift direction.


## 0.1-dev15

- Generalises machinery harmonic analysis into reusable `SpectralObservations.cls`.
- Adds sampled scalar histories with mean/RMS and selected spectral-component observations.
- Adds explicitly named statistical RMS aggregation for incoherent pressure/source contributions.
- Retains `HarmonicSampleHistory` as a compatibility subclass so dev13/dev14 machinery clients continue to run.
- Adds an 83,500-source scaling boundary test proving incoherent RMS contributions scale as sqrt(N), not N-amplitude multiplication.


## 0.1-dev14

- Adds `RotatingVibration.cls` with explicit linear rotor/shaft modal mass, stiffness and damping.
- Adds resolved natural-frequency and damped time-domain response; modes consume physical force histories rather than arbitrary vibration factors.
- Adds `ContactFrictionExcitation` with explicit normal load, relative tangential velocity, friction force and dissipated power.
- Adds `RotorVibrationExperiment` to retain displacement histories for the dev13 harmonic observer.
- Qualified 50 Hz modal frequency, resonant forced response, 30 N kinetic friction/60 W dissipation, and damping-energy decay.
- Inspected Physical Manufacturing dev2, Materials dev1 and Parts dev2 and preserved their authority boundaries; none is embedded in Physics.


## 0.1-dev13

- Adds `RotatingMachinery.cls` as a general mechanics layer for rotating assemblies rather than a lathe-specific model.
- Adds explicit mass eccentricity/imbalance forcing using rigid-body angular state and offset geometry.
- Adds compliant radial bearings with stiffness, damping and optional rotational drag.
- Adds explicit rotational viscous friction with torque and dissipated-power evidence.
- Adds harmonic observations computed from sampled physical histories; harmonics are measured, not injected.
- Adds focused qualifications for imbalance force, bearing restoring force, frictional dissipation and measured 20/40 Hz spectral components.


## 0.1-dev12

- Adds `ExternalFluidParcels.cls`: escaped liquid continues as conservative ballistic parcel state after leaving a breached vessel.
- Adds gravity integration and explicit plane contact with restitution and impulse evidence for external parcels.
- Adds `EscapedFluidWorldBinding` to transfer each retained breach parcel exactly once into the external parcel world while preserving retained+external mass accounting.
- External parcels preserve original `EscapedFluidParcel` provenance; no conversion into anonymous particles.
- Deliberately does not claim CFD, puddle spreading, splash breakup, parcel merging, re-entry, pressure fields or shard-fluid coupling.
- Adds four focused qualifications for ballistic motion, floor contact, retained+external mass conservation and provenance boundary.


## 0.1-dev11

- Adds `FluidContainment.cls`: explicit 2-D containment state, hydraulically active wall breaches, conservative discharge and retained escaped-fluid parcels.
- Adds `FractureContainmentBinding2D`: a fracture event opens only the breach explicitly bound to the failed structural link; a fracture that does not connect wet interior to exterior does not leak.
- Adds `RectangularBoundaryBreach2D` with explicit side, position, sill, opening dimensions and discharge coefficient.
- Adds `BreachedFreeSurfaceVessel2D` using `Q = Cd A_sub sqrt(2 g h)` with caller-supplied `Cd`; no hidden spill factor.
- Adds `EscapedFluidParcel` so discharged water retains mass, volume, position, velocity, release time and breach provenance.
- Adds conservative cell drainage to `RectangularTankSlosh2D`; retained liquid momentum is reduced with removed volume while retained-cell velocity is preserved.
- Fixes `RectangularTankSlosh2D~currentMass` to retain 50-digit working precision at the Units/fluid scalar boundary.
- Fails closed when containment becomes `FRAGMENTED`, because moving shard boundaries exceed this rectangular breached-vessel model.
- Adds four focused containment qualifications covering mass conservation, hydrostatic head, fracture-to-breach activation and fragmented-boundary fail-closed behavior.


## 0.1-dev10

- Rebased directly on the user-supplied current Physics World v0.1-dev9(1) authority (SHA-256 `89b83dee9fda3566291ac41b4a097db1ce3afbc318c3daf47762b346b8c0e5bd`).
- Merges the parallel two-axis slosh work into the same Physics line rather than maintaining a competing Physics package.
- Adds `FreeSurfaceFluids2D.cls` with conservative two-horizontal-axis nonlinear shallow-water evolution (`h`, `qx`, `qz`) for rectangular tanks.
- Adds simultaneous X/Z vessel-frame forcing, four-wall reflecting boundaries, two-dimensional CFL enforcement, moving 3-D liquid centre of mass, two-axis momentum/energy and X/Z natural-period observations.
- Adds four-wall hydrostatic vessel load integration and `FreeSurfaceVesselCoupling2D` over the existing authoritative `RigidBodyState`/`PhysicalPose`.
- Adds five focused 2-D slosh qualification fixtures and `examples/sloshing_tank_2d.rex`.
- Retains dev9 driven acoustics and thermal modules unchanged, along with all inherited optics/mechanics/deformable/acoustic/fluid/electromechanical/free-surface APIs.
- Preserves fail-closed behavior for dry fronts, rim reach/spill, loss of positive floor-normal effective gravity and CFL violation.

## 0.1-dev9

- Adds `DrivenAcoustics.cls` for continuous actual-mechanics -> acoustic-pressure coupling.
- Adds `RigidRadiatingPatch` / `RadiatingPatchObservation` with retained world position, normal velocity/acceleration, area, volume velocity and volume acceleration.
- Adds retarded-time `ContinuousMechanicalAcousticRenderer` producing the existing `AcousticSampleBuffer`; direct-path transmission and shared acoustic media remain authoritative.
- Adds an end-to-end voice-coil/spring/diaphragm qualification proving pressure comes from resolved diaphragm motion rather than electrical current gain.
- Adds `Thermal.cls` with lumped thermal nodes, typed heat-power observations, material specific heat/conductivity, conduction, explicit-coefficient convection and grey-body radiation.
- Preserves causal authority: electromechanical `unassignedTerminalPower` is not automatically treated as heat; an explicit `ThermalPowerObservation` is required.
- Adds thermal power, transfer and fail-closed qualification plus speaker and electrical-heating examples.
- Retains Maths v0.8 and Units v0.1-dev4 as external authorities and preserves all prior optics/mechanics/deformable/fluid/free-surface/acoustic/electromechanical APIs.
- Current boundary: no finite-piston directivity/baffle diffraction, acoustic back-loading, continuum thermal PDE, phase change or automatically derived convection.

## 0.1-dev8

- Adds `Electromechanics.cls` as a reciprocal electrical↔mechanical transduction boundary over existing rigid-body state.
- Adds Units-typed `ElectricalDriveObservation` with causal/source/evidence retention.
- Adds ideal reciprocal linear force transducers (`F=K i`, `e=K v_rel`) and rotary torque transducers (`tau=K i`, `e=K omega_rel`).
- Applies optional equal-and-opposite reaction force/torque to a physical stator body rather than deleting reaction momentum.
- Adds typed actuation events with terminal power, conversion power, mechanical power, back EMF and explicit unassigned-terminal-power evidence.
- Adds qualification for linear actuation, reaction momentum conservation, rotary actuation, dimensional fail-closed behavior and reciprocal power closure.
- Preserves the Physics dev7 free-surface work and the Rexx-tronics optical compatibility surface unchanged.
- Does not claim magnetic-field solution, nonlinear solenoid behavior, winding inductance/commutation or continuous driven-speaker radiation.


## 0.1-dev7

- Rebased directly on user-supplied Physics World v0.1-dev6 (SHA-256 `cea7da7491e341a89d1b072c9dff625aa3ee70e509ec45664c64b23aabd2cfb8`).
- Adds `FreeSurfaceFluids.cls` with an explicit conservative one-dimensional nonlinear shallow-water solver for rectangular tanks.
- Adds Rusanov finite-volume fluxes, reflecting end walls and an explicit per-state CFL timestep guard.
- Adds evolving free-surface depth/discharge, mass/volume conservation, moving liquid centre of mass, relative momentum and mechanical-energy observations.
- Adds shallow-water fundamental-period observation and a deterministic seeded first mode for qualification.
- Adds resolved end-wall/floor vessel load projection with local force/torque evidence.
- Adds `FreeSurfaceVesselCoupling` for explicit kinematic forcing and staggered submission of slosh loads to `RigidBodyState`.
- Fails closed on dry/near-dry cells, rim reach/spill, loss of positive floor-normal effective gravity and CFL violation.
- Retains `ContainedFluidLoad` for sealed/retained-liquid cases where internal slosh is intentionally ignored.
- Adds mass-conservation, forcing, natural-period sign reversal, spill guard and vessel-coupling qualification fixtures plus `examples/sloshing_tank.rex`.
- Preserves Units v0.1-dev4, Maths v0.8 and the Rexx-tronics dev8 optical compatibility surface.

## 0.1-dev6

- Merges the dev5 fluid foundation with the dev4.2 mechanics-to-acoustics line rather than dropping either branch.
- Advances the external Units authority to user-supplied ooRexx Units v0.1-dev4; Physics still exports no private unit facade.
- Adds `ContactDynamics.cls` with explicit finite box/cylinder support hulls, off-centre rigid-plane contact, rotational effective-mass impulse response and caller-supplied constant Coulomb friction.
- Adds `RigidTumbleTracker`, which integrates actual angular travel and counts contact events instead of using a tumble/alignment heuristic.
- Adds solid/hollow cylinder rigid-body mass properties and a mechanics start-time boundary for analytically prepared drop states.
- Adds `VesselDynamics.cls` with ideal `FreeFallDrop`, retained `ContainedFluidLoad`, liquid-volume input via shared Units, `VesselImpactExperiment` orchestration and `VesselImpactReport`.
- Retains dev4.2 `MechanicalAcoustics.cls`: contact events can excite explicit structural modes and render retarded microphone pressure; dev6 vessel tests use that path to report Pa and dB SPL.
- Adds a 1 m retained-liquid vessel / metal-sheet integration qualification with 250 mL water, finite contact, tumble rotation, structural acoustic coupling and microphone pressure.
- Preserves the Rexx-tronics dev8 documented Physics dev4 optical consumer surface and adds `test_rexxtronics_dev8_optical_contract.rex`.
- Hardens new scalar UnitQuantity boundary coercions to avoid accidental default-precision truncation; new fluid analytical methods use explicit working precision.
- Qualifies 49 Physics tests in independent processes against ooRexx r13196, authoritative Maths v0.8 and Units v0.1-dev4; all nine Physics `.cls` sources compile with `rexxc`.
- Deliberately does not claim open-vessel free-surface/slosh/spill physics, automatic glass fracture, general mesh contact or full CFD.

## 0.1-dev5

- Rebases directly on the user-supplied dev4 acoustics/mechanics/optics baseline.
- Advances the external unit dependency to the supplied ooRexx Units v0.1-dev3 package; Physics still exports no private unit facade.
- Adds `Fluids.cls` as a peer solver family over the same `PhysicalWorld`.
- Extends `PhysicalWorld` / `PhysicalMediumRegion` additively with ambient/spatial fluid-medium authority and `fluidMediumAt(point)`.
- Adds constant-property Newtonian `FluidMedium` with density, dynamic viscosity and kinematic viscosity observations.
- Adds `UniformFluidField`, `HydrostaticFluidField`, `RigidRotationFluidField`, typed `FluidState` and field sampling.
- Adds Reynolds-number and dynamic-pressure helpers.
- Adds exact Hagen-Poiseuille straight circular laminar-pipe flow with flow rate, mean/centreline/radial velocity, mass flow, wall shear, pressure gradient and explicit laminar-regime evidence.
- Adds RK4 `FluidPathlineIntegrator` and inspectable tracer samples.
- Adds `FluidProbe` over any live pose provider.
- Adds explicit fully-submerged buoyancy + caller-supplied constant-Cd drag coupling into existing `RigidBodyState` force accumulation.
- Adds qualification fixtures for shared fluid regions, hydrostatics, rigid rotation, pipe flow, pathlines, units and rigid-body coupling.
- Deliberately does not claim general CFD, turbulence, free surfaces, compressibility, multiphase flow, cavitation, non-Newtonian rheology or partial-submersion modelling.

## 0.1-dev4

- Merges the user-supplied acoustic Physics branch forward onto the dev3.2 deformable/Units baseline rather than replacing it.
- Adds `Acoustics.cls` as a peer solver over the same `PhysicalWorld`, body identities, poses and spatial medium regions.
- Adds `Coupling.cls` with live `PhysicalMount` and optical beam instrumentation used for cross-domain qualification.
- Generalises world bodies/regions with `PhysicalBody`, `PhysicalMediumRegion`, `OpticalMediumRegion` and `AcousticMediumRegion`; optical-only, acoustic-only and combined regions share spatial authority.
- Adds acoustic density, sound speed, impedance, attenuation, wavelength, wavenumber and propagation-delay modelling.
- Adds coherent acoustic phasors, ideal tone sources, microphones/readings/path evidence and phase-correct interference.
- Adds acoustic impedance interface calculations and finite rectangular first-order specular reflection.
- Adds body/mount-attached sources and microphones; qualification proves mechanics-moving shared poses are observed by acoustics without coordinate-copy callbacks.
- Preserves mixed-medium acoustic propagation as fail-closed until explicit segmented interface propagation is implemented.
- Migrates the acoustic branch from its historical Physics unit facades to direct ooRexx Units v0.1-dev2 authority. No `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` or Physics-local `SI` API is reintroduced.
- Adds typed acoustic UnitQuantity inputs/outputs for Hz, W, Pa, kg/m^3, m/s, delay, wavelength and acoustic impedance.
- Adds `AcousticSignalRenderer` and `AcousticSampleBuffer` to reconstruct solved phasors into time-domain pressure samples in pascals with sample-rate/time evidence for Audio/DSP consumers.
- Adds `test_acoustic_signal_render.rex`; 1 kHz for 1 ms at 48 kHz produces 48 pressure samples and preserves solved RMS pressure.
- Retains all dev3.2 deformable-body, rigid-mechanics and optics capabilities and tests.
- Requalifies acoustic, optical, rigid, deformable and shared-unit tests against real Maths v0.8, Units v0.1-dev2 and ooRexx r13196.

## 0.1-dev3.2

- Removes the old `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` and `SI` compatibility facades completely.
- Makes ooRexx Units v0.1-dev2 the sole unit/dimension/quantity authority at Physics public boundaries.
- Converts remaining Physics tests/examples to direct `Units` / `UnitQuantity` use.
- Adds a qualification guard that fails if the removed facade classes or call forms are reintroduced into executable Physics source, tests or examples.
- Requalifies the complete optics + rigid mechanics + deformable suite against authoritative Maths v0.8, Units v0.1-dev2 and ooRexx r13196.

## 0.1-dev3

- Adds deformable-body mechanics with mass nodes, axial constitutive links, elastic energy, permanent set, fracture, energy accounting and rigid-plane contact.

## 0.1-dev2.1

- Corrects mechanics vector scaling for authoritative Maths v0.8: use `vector * (1/scalar)` rather than unsupported `vector / scalar`.

## v0.1-dev10.1 — merged dev10 authority

- Merges the parallel dev10 2-D free-surface lane with the dev10 brittle-fracture lane.
- Retains `FreeSurfaceFluids2D.cls` and its five 2-D slosh/vessel-coupling fixtures.
- Adds `Fracture.cls` and the fracture-enabled `Deformable.cls` from the fracture lane.
- Broken deformable links stop carrying load and expose retained fracture evidence plus connected fragment topology.
- No fracture energy is silently converted to heat or sound; unresolved released energy remains explicit evidence.

## 0.1-dev18
- Adds reduced-order propulsion authority with explicit operating-point/map interface and deterministic fuel-mass accounting.
- Adds wheel/tyre rolling resistance, touchdown slip/spin-up, dissipated contact energy and calibrated energy-based wear evidence.
- No universal engine deck, rolling coefficient or tyre-wear constant is invented.

## 0.1-dev19
- Adds `LandingGearDynamics.cls`: explicit strut force/damping provider boundary, vertical touchdown state, normal-load evidence and direct coupling into dev18 wheel/tyre slip, spin-up, dissipation and wear.
- Adds the hard-landing energy-square acceptance boundary: doubling vertical touchdown speed quadruples vertical kinetic energy.

## 0.1-dev20
- Adds `AircraftGroundDynamics.cls` for reduced-order multi-station landing/ground-roll composition.
- Explicit gear load shares must sum to one and fail closed otherwise.
- Each station couples its landing-strut normal load to its own tyre state; aircraft ground speed responds to summed tyre resistance.

## 0.1-dev21
- Adds `AircraftGroundLoadTransfer.cls` with explicit longitudinal gear geometry and quasi-static normal-load resolution.
- Braking acceleration transfers load toward the nose gear from actual mass, wheelbase and COM height.
- Resolved negative gear loads fail closed rather than silently clamping an invalid contact regime.

## 0.1-dev22
- Adds `AircraftDynamicGroundRun.cls`, feeding dev21 geometry-derived nose/main axle loads into individual dev18 tyre states during a deterministic ground run.
- Main left/right split remains explicit pending lateral-transfer physics.
- Individual tyres now accumulate different dissipation/wear histories when their resolved normal loads differ.
- Library peer refresh records Parts v0.1-dev11 and Materials v0.1-dev6; neither yet contains aircraft landing-gear/tyre catalogue families, so no catalogue data is invented here.

## 0.1-dev23
- Adds `AircraftLateralLoadTransfer.cls`: explicit track width/COM height quasi-static left/right axle load transfer.
- Positive aircraft-right lateral acceleration transfers normal load toward the left side; total axle normal load is conserved.
- Negative resolved tyre contact load fails closed.
- Library review also found substantial newer reusable objects across Migratable Job, Vision/video projection, Physical Manufacturing, Storage Fabric, Wire UI Windows/3D and other platform work; none is silently made a Physics dependency.

## 0.1-dev24
- Adds `AerodynamicCoefficientTables.cls`: bounded 1-D coefficient tables, explicit aerodynamic operating state and a longitudinal CL/CD/CM table model.
- Lookup interpolates within the qualified domain and fails closed outside it; no silent aerodynamic extrapolation.
- Lift, drag and pitch moment derive from dynamic pressure and explicit reference area/chord.
- Library refresh inspected the new Azure bulk Parts delivery: 93 research candidates across fasteners, bearings, shafts, gears, springs, resistors, capacitors, diodes, connectors and structural stock. They remain research candidates rather than silently promoted physical truth.

## 0.1-dev25
- Adds bounded bilinear `AerodynamicCoefficientSurface2D` and `LongitudinalAerodynamicSurfaceModel` for explicit CL/CD/CM(alpha,Mach)-style data.
- Adds `AircraftCombinedGroundLoadModel`, composing longitudinal nose/main and lateral left/right equilibrium without configured whole-aircraft load percentages.
- Aerodynamic surfaces fail closed outside both qualified axes; ground-load composition conserves total normal load.

## 0.1-dev26
- Adds `AircraftGroundAerodynamicLoading.cls`, an explicit quasi-static bridge from aerodynamic vertical force and pitch moment into nose/main ground-contact loads.
- Remaining ground normal load is `m*g - upward aerodynamic force`; pitch moment redistributes that load across the explicit wheelbase.
- Conditions representing aerodynamic liftoff or negative axle contact fail closed.

## 0.1-dev27
- Adds `AircraftStaticLateralLoads.cls` for static lateral payload/CG offset, deliberately separate from acceleration-driven dev23 load transfer.
- `StaticLateralMassElement` carries explicit mass and lateral position; centred mass contributes weight but zero roll moment.
- Negative port/starboard reaction fails closed as loss of the assumed two-sided contact state.
- Adopts Maths v0.9 as the qualification peer; Physics retains physical interpolation semantics while Maths now supplies reusable high-precision/interpolation foundations.

## 0.1-dev28
- Adds `AircraftFluidLateralLoads.cls`, replacing the demo's hand-written static-plus-slosh roll-moment composition with a reusable Physics object.
- Fluid mass remains represented exactly once in the static payload model; the dynamic composition adds only the free-surface solver's resolved roll torque.
- Combined negative gear reaction fails closed.

## 0.1-dev29
- Adds `FreeSurfaceCflDiagnostic2D` and `RectangularTankSlosh2D~cflDiagnostic`.
- Reports the exact cell controlling the explicit CFL limit, including h, qx/qz, |u|/|w|, wave speed, x/z rate contributions, stable dt and h/minimumDepth ratio.
- Does not alter CFL, cap amplitude, add artificial damping, or claim wetting/drying support.

## 0.1-dev30
- Introduces the package-wide `PhysicalWorld` freeze/restore spine in `PhysicsFreeze.cls`.
- `PhysicalWorld~freeze` captures coherent world time, every registered body's pose, and a schema-identified inventory of stateful continuation participants.
- Restore validates participant identity/schema inventory before mutation and fails closed on mismatch.
- Adds first continuation participants for `RigidBodyState` and `RectangularTankSlosh2D`; the latter retains every h/qx/qz cell plus solver time/effective-gravity state.
- Adds `advanceCfl` bounded subcycling for valid wet-state caller timestep mismatch; it does not add wetting/drying or hide model-domain exhaustion.
- `FREEZE_COVERAGE.md` explicitly audits remaining stateful domains; dev30 does not claim complete durable freeze coverage yet.

## 0.1-dev31
- Adds `AcousticImpulseResponse.cls`: a reusable forward source->scene->receiver acoustic oracle with no localisation semantics.
- Returns ordered arrivals with source/interaction/receiver path vertices, path length, propagation delay, per-band complex pressure phasor, and energy proxy.
- Adds explicit frequency-band surface reflection/transmission data through `AcousticSpectralMaterial`.
- Adds bounded first-order doorway/corner diffraction through explicit `AcousticDiffractionPoint` geometry and evidence-supplied spectral diffraction transfer. Geometry/delay/spreading/phase are solved by Physics; dev31 deliberately does not invent diffraction coefficients.
- Adds first-order finite specular reflection, finite-wall transmission, 150 ms-style bounded early-arrival windows, moving-source trajectory sampling, source/sound-speed uncertainty envelopes, and generic multi-candidate `AcousticForwardOracle`.
- Adds optional `PhysicsJournalState.cls` adapter to the common Journal Pointed State v0.1 `StateOfNationController`. A coupled simulation may inject one shared controller; Physics does not require a private incompatible State-of-the-Nation authority.


## v0.1-dev32
- Added `AcousticBuildingMaterialFactory` with explicit mass-law spectral presets for closed solid-wood doors and breeze-block walls. Thickness and density are caller-visible parameters.
- Added `AcousticVerticalPanel`, a finite vertical floor-plan surface implementing the `segmentHit` / `reflectionPoint` protocol consumed by `AcousticSpectralSurface`.
- This lets building models use actual transmitting/reflecting wall and door surfaces instead of treating every partition as acoustically rigid.
- Added focused building-acoustics test covering spectral material ordering, finite panel intersection, and a transmitted closed-door path.

## v0.1-dev33
- Building-acoustics qualification exposed a zero-distance point-source/receiver singularity in AcousticImpulseResponse~pathPhasor; it now fails closed with zero phasor rather than dividing by zero.
- Added executable F11 scene-grid qualification harness using breeze-block walls and solid-wood doors.

## v0.1-dev36 — F11 continuous vehicle trajectory sampling
- Vehicle is now a continuous 40 km/h trajectory rather than five teleported snapshots.
- LTR trajectory starts at x=-4 m and crosses x=-4,2,8,14,20 m at t=0,0.54,1.08,1.62,2.16 s.
- RTL trajectory starts at x=20 m and crosses x=20,14,8,2,-4 m at the same sample times.
- Five sample states are observations of one continuously moving vehicle; velocity remains live at each sample for Doppler.
- Summary/path CSVs now retain sample_time_s.
- AcousticMovingVehicle adds timeAtX/timeAtCenter/centerExtentAt trajectory helpers.

## v0.1-dev37
- Corrects the F11 vehicle experiment so the finite 4 m x 1.5 m moving vehicle body participates as an actual acoustic reflector for stationary source noise.
- Adds opt-in `AcousticDiffuseReflector` and bounded `AcousticVerticalPanel~scatterPoint`; this models finite-body scattering separately from mirror/specular building reflection.
- The F11 car is retained as a rigid upper-bound test surface and is registered for both obstruction/specular handling and finite diffuse reflection.
- Stationary-noise paths reflected by the moving vehicle now use moving-reflector Doppler (`AcousticDoppler~movingReflectionObserved`) in path evidence.
- Adds executable regression test requiring a vehicle-reflected path, increased received energy versus no-car control, and a non-zero moving-reflector Doppler shift.

- Dev37 correction after inspection of the completed dev36 experiment: dev36 registered a specular vehicle panel but produced zero vehicle-reflection paths for stationary noise. Elevated source/receivers at z=4.8 m cannot mirror-reflect through a 1.5 m vertical side in that geometry.
- Vehicle coupling is therefore modeled explicitly as finite-body diffuse/bistatic scattering rather than falsely forcing a mirror-specular solution.
- Scattered pressure now uses two spherical-spreading legs and an explicit effective scattering cross-section, avoiding the erroneous one-leg pathPhasor(totalDistance) energy model.
- The F11 vehicle effective rigid side scattering cross-section is 4.0 m x 1.5 m = 6.0 m^2.
- The car own source is no longer allowed to reflect from the same idealized car surface carrying that source.

## v0.1-dev38
- Extends the forward acoustic oracle with an opt-in bounded second-order early-arrival solver, without changing the established `solve()` first-order contract.
- `solveEarly(..., maxInteractions=2)` now enumerates diffraction->diffraction, finite reflection->diffraction, and diffraction->finite reflection paths in addition to dev37 first-order direct/transmitted, specular, diffuse and diffraction arrivals.
- Every second-order path remains geometry/evidence-bearing and is bounded by the caller's early-arrival window (normally 150 ms); no unbounded ray tracing or guessed higher-order tail is introduced.
- Adds `AcousticImpulseArrival~interactionCount`, `pathSignature`, and receiver `arrivalsByKind` to make Audio/forensic consumers able to inspect physical route evidence without reconstructing it from solver internals.
- Keeps the F11 experiment outside the reusable solver: no observed TDOA, room hypothesis, localisation score or event label is used to admit paths.

## v0.1-dev39
- Adds `GuitarStringMagnetics.cls` as the Physics half of the electric-guitar proof.
- Adds `GuitarStringPhysicalModel`: damped stiff-string modal displacement/velocity at arbitrary normalized string position, including fret length/frequency, inharmonicity, modal damping and articulation-dependent damping.
- Adds `MagneticFluxGeometry` and `GuitarStringMagneticFluxProbe`: string displacement is converted to magnetic flux through an explicit local flux-displacement gradient supplied as physical/calibration evidence.
- Adds `PhysicsMagneticFluxObservation`, retaining simulation time, flux, string displacement, string velocity, source and evidence.
- Deliberately stops at magnetic flux. Pickup turns/winding RLC, Faraday voltage, pots/cable/amplifier and other electrical state remain Rexx-tronics authority.

## v0.1-dev39.1
- Runtime qualification repair using the user-supplied ooRexx 5.3.0 r13196 debug package.
- Replaces non-integer `**` operations in guitar frequency/inharmonicity calculations with RxMath exponential/square-root operations, because ooRexx `**` requires an integral exponent.
- Repairs the guitar qualification fixture and verifies the real Physics -> Rexx-tronics Faraday seam.

## v0.1-dev40
- Adds `GuitarStructuralCoupling.cls`: reduced-order string -> bridge -> guitar-body mechanical energy transfer.
- Adds evidence-bearing `GuitarBodyMode`, `GuitarBodyModeResponse`, `GuitarBridgeCoupling`, and `GuitarBridgeExcitation`.
- Extends `GuitarStringPhysicalModel` with public modal amplitude, effective mass, linear-density, tension and mode-count evidence so coupled mechanical calculations do not duplicate hidden string assumptions.
- Bridge transfer is energy-budgeted and fails closed if body-mode allocation exceeds transferred string energy.
- The same string excitation can now produce two independent physical observations: magnetic flux for Rexx-tronics and mechanically radiating guitar-body motion for acoustics.

## v0.1-dev41
- Adds `GuitarCoupledBoundary.cls`, a reciprocal reduced-order string/body mechanical boundary.
- Equal/opposite coupling force now permits body motion to alter string motion; the previous dev40 energy-partition model remains available as the simpler one-way reduced-order approximation.
- Adds `GuitarCoupledOscillator` and `GuitarCoupledBoundaryFactory` for modal string/body state with explicit mass, frequency, damping, displacement, velocity and energy.
- Demonstrates sympathetic excitation: a second initially silent string acquires mechanical energy through the shared body boundary.
- Records per-step coupling force and before/after mechanical-energy evidence for qualification and later checkpoint integration.

## v0.1-dev43
- Adds monitor-speaker acoustic pressure -> all strings/body feedback upstream of magnetic pickup observation.
- Adds evidence-bearing `GuitarAcousticPressureObservation`, `GuitarAcousticForceCoupling`, and `GuitarAcousticFeedbackDriver`.

## v0.1-dev44
- Adopts the user-supplied sealed Maths v0.10 API for sampled guitar modal evaluation.
- Adds `GuitarMathsModalRenderer`, mapping Physics-owned string modes onto Maths `MathDampedOscillatorBank` without moving string/material semantics into Maths.
- Adds chunk-addressable sampled displacement and pickup-flux blocks, preserving simulation sample/time continuity for journal/checkpoint workflows.
- PURE qualification compares Maths-rendered samples against the existing Physics scalar string model. A BINARY64/NUMPY context selects the v0.10 native oscillator-bank lane when its Foreign Runtime provider is installed.
- Does not invent the proposed `MathSecondOrderLinearSystem`; reciprocal coupled stepping remains Physics scalar code until Maths publishes that generic numerical contract.

## v0.1-dev44.1
- Requalifies dev44 against the recovered Library Foreign Runtime v0.22.6 and the exact user-supplied ooRexx r13196 debug runtime.
- Confirms the Physics guitar modal renderer executes through Maths v0.10's real BINARY64/NUMPY provider and retains NUMPY provider evidence.

## v0.1-dev45
- Adopts Maths v0.11 `MathSecondOrderLinearSystem` for the reciprocal six-string/body guitar dynamics.
- Adds `GuitarMathsDynamicsProjection`, which projects Physics-owned masses, damping, stiffness, nut/bridge topology and current state into generic M/C/K coordinates.
- Adds accelerated `advanceInstrument` using Maths `integrateFinal(...,'SYMPLECTIC_EULER')`; returned state is written back into the existing Physics oscillator objects and Maths evidence is retained in the Physics ledger.
- Preserves the dev43 numerical integration method while moving numerical propagation out of the per-mode ooRexx loop.

## v0.1-dev46.2 — microphone-history render fast path
- Retarded drum-history interpolation now searches backward from the newest FIFO sample, matching monotonic microphone observation and avoiding O(full-history) scans per sample.
- `DrumKitPhysics` caches pi once for compact-radiator pressure observations instead of re-evaluating RxMath arctangent at audio rate.

## v0.1-dev46.3 — fixed-microphone acoustic plan
- Adds `DrumPressurePlan` / `DrumPressurePath` and `preparePressurePlan()` for fixed kit/listener geometry.
- Cached paths retain only invariant propagation delay and compact-radiator pressure gain; live modal acceleration remains sampled from the authoritative acoustic history on every observation.
- `pressureAtPlan()` is semantically equivalent to `pressureAt()` for unchanged geometry/medium/surfaces while avoiding repeated MathVector distance and acoustic-path work at audio rate.

## dev46.7 band concurrency / fixed-microphone path
- Adds `DrumKitPhysics~stepWithoutHistory(dt)` for forward-only real-time rendering where general retrospective history is not required.
- Adds `DrumFixedMicStream`, a fixed-listener causal fractional-delay observer using the same compact-radiator gains/delays as `preparePressurePlan()`.
- Removes per-step structural force `.Directory` allocation: modes carry transient coupling-force scalars and reciprocal links accumulate equal/opposite forces directly.
- General history/pressure APIs remain unchanged for arbitrary retrospective observations and checkpoint evidence.
- Fixed-mic equivalence fixture: max difference about 1.13e-5 Pa against the general pressure-plan observer on an 8.55 Pa peak snare strike at 6 kHz.

## dev46.8 acoustic block feedback
- Adds `GuitarAcousticBlockFeedbackDriver`: a pressure-history block is converted by Physics into a complete force-history matrix and advanced through Maths v0.14 second-order continuation.
- Every string mode, including intentionally unplayed courses, and every body mode receives pressure-derived force before magnetic pickup observation.
- Adds `GuitarMathsDynamicsProjection~acousticForceVector()` / `acousticForceHistory()`; Physics retains effective-area/modal-participation semantics while Maths owns numerical propagation.
- Block feedback retains source/path/coupling/Maths evidence and exposes continuation snapshot/restore for journal-pointed simulation continuation.
- PURE and live SCIPY/Foreign Runtime qualification both passed on the supplied r13196 runtime.
- Photo World dev10 was inspected as a peer geometry consumer. Physics does not depend on Photo World: Photo already depends on Physics, so importing its survey classes here would create the wrong authority direction/cycle.

## dev47 — 2026-09-27 portfolio review refresh
- Rebased the F11 deterministic warbler / moving-reflector Doppler experiment from dev38 onto the current dev46.8 acoustic-block-feedback Physics head.
- Qualification dependency advanced to ooRexx Maths v0.16.
- PHYS-001: in-memory checkpoints now bind to their originating PhysicalWorld and exact ordered body-object inventory; cross-world or changed-body restores fail before mutation.
- PHYS-002: restore order is captured explicitly and restore is transactional; body poses, participant continuation state and simulation time roll back if a participant restore fails.
- Restored the legitimate AcousticMovingVehicle~origin accessor required by retarded-time Doppler reconstruction; the erroneous noise-component origin accessor from dev38 was not reintroduced.

## 0.1-dev48 — F11 rear exterior + Cluster candidate workflow

- Added authoritative excavated rear exterior geometry: lower paved level z=0, rear
  hard terrain step 4 m behind the property rising 1.5 m, and a 1 m x 2 m ground-level
  stairwell aperture.
- Added `F11RearExteriorGeometry` and wired it into both F11 vehicle and warbler
  experiments. The stairwell opening is represented as missing wall geometry, not a
  low-transmission material.
- Added `F11AcousticCandidateTrajectoryTask`, a cluster-unaware ordinary ooRexx work
  object, plus an external adapter/workflow for the existing `cluster.object.peer/0.1`
  transport.
- Candidate trajectory is the preferred cluster work unit so pitch, cadence, power,
  delay and overlap curves remain trajectory-coupled.
- Destination-local acoustic context is passed via `LOCAL_REF`; heavy PCM/FFT/Physics
  state does not travel in the object envelope.
- Added loopback Cluster contract test, rear geometry test and rear surface test.

## 0.1-dev49 — F11 Cluster batch fan-out
- Added deterministic candidate batch planning and round-robin assignment over existing Cluster object hosts.
- Added whole-trajectory batch runner using ownership-fenced MOVE then destination-local CALL; no 20 ms message fan-out.
- Added `physics.f11.candidate-summary/2` with pitch, cadence, power, reflection-delay, overlap and vehicle-subtracted residual evidence references.
- Added executable three-destination/four-candidate batch qualification.
