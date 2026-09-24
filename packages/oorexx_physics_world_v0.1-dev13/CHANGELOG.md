# Changelog

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
