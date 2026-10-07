## dev46.6 Maths v0.14 causal continuation

This candidate rebases the accelerated guitar dynamics seam onto sealed ooRexx Maths v0.14. `GuitarMathsDynamicsProjection` now exposes continuation objects backed by `MathSecondOrderContinuation`, supports block-wise state writeback through `advanceContinuationBlock`, and delegates pi to Maths' named-constant authority while building the coupled M/C/K system.

The qualification fixture advances the same 32-DOF six-string/body system as one monolithic 1,200-step solve and as twelve 100-step continuation blocks using the SCIPY provider. Final states agree within `2.4E-12 m` displacement and `1.51E-9 m/s` velocity. Maths v0.14 sample-delay snapshot/restore is also exercised as the checkpointable causal boundary for future monitor feedback.

## dev46.1 drum-kit repair

The dev46.1 candidate fixes the drum acoustic-history FIFO, caches per-mode invariant dynamics, and adds reciprocal structural coupling between connected kit members. See `VALIDATION_DEV46_1.txt`.

# ooRexx Physics World v0.1-dev17

A shared physical-world library for ooRexx. Physics World keeps one authoritative body identity, pose and spatial-medium model while domain solvers operate over that same world.

Current executable solver families are geometric optics, rigid mechanics, deformable mechanics, impact and continuously-driven mechanics-to-acoustics coupling, coherent geometric acoustics, fluid statics/dynamics, finite rigid contact/tumble, retained-liquid vessel loading, explicit one- and two-horizontal-axis free-surface slosh solvers, reciprocal electromechanical actuation, and first lumped thermal dynamics.

## Dev17: deterministic aerodynamic flight

`BallisticFlight.cls` composes Mechanics and dev16 rigid-body aerodynamics into a deterministic flight experiment. `RugbyBallFlightFactory` consumes Parts projection values for mass, length and maximum circumference, builds a prolate-body reference inertia and advances translation, spin and orientation under gravity plus aerodynamic force/torque.

The flight model remains coefficient-driven and reduced-order. It does not claim experimentally fitted rugby-ball coefficients, CFD, deformation or bounce.

## Dev16: orientation-sensitive rigid-body aerodynamics

`RigidBodyAerodynamics.cls` adds a general aerodynamic body model over Mechanics rigid-body state. Forces use wind-relative velocity, physical projected dimensions and explicit coefficient models. An axial/broadside reduced-order model changes projected area and drag with attitude and exposes explicit extension coefficients for spin lift and aerodynamic spin damping.

`SportsBallAerodynamicProjection~createRugbyLeague` consumes the Parts sports-ball projection (`LENGTH`, `MAX_CIRCUMFERENCE`) but does not depend on Parts at runtime. Parts remains catalogue authority. Physics requires aerodynamic coefficients to be supplied/fitted; it does not invent them from `RUGBY-LEAGUE-BALL-GENERIC`.

This is not CFD and the current projected-area law is a reduced-order axial-body approximation.

## Dev15: general spectral observations and distributed-source aggregation

`SpectralObservations.cls` lifts sampled-signal analysis out of rotating machinery. Mechanics and acoustics can now share the same scalar time-history and spectral-component evidence. `IncoherentSourceAggregator` explicitly performs statistical RMS pressure/source aggregation; it must not be confused with coherent pressure summation.

A qualification with 83,500 equal incoherent contributions resolves to `sqrt(83500) ≈ 288.9637` times one contribution, deliberately rejecting the physically wrong 83,500-times pressure-amplitude shortcut.

This is infrastructure for distributed crowd/stadium acoustics, not yet a stadium reverberation/diffraction solver or cognition model.

## Dev14: shaft/rotor vibration and friction excitation

`RotatingVibration.cls` adds reusable modal shaft/rotor response. Each mode has explicit modal mass, stiffness, damping, direction, displacement and velocity. Natural frequency follows from those physical values, and applied world forces excite the time-domain state. Contact friction derives opposing force from normal load and relative sliding velocity and reports mechanical dissipation.

The displacement history feeds dev13's harmonic observer, so resonance and harmonics remain consequences/measurements of resolved physical histories rather than authored effects.

Physical Manufacturing dev2 already provides finite-force machine-axis dynamics and explicit projected part masses. Materials dev1 owns material reference properties/projections. Parts dev2 owns reusable part identity/defaults. Physics deliberately does not absorb those authorities.

## Dev13: rotating machinery, imbalance, bearings, friction and harmonics

`RotatingMachinery.cls` adds reusable rotating-assembly physics. `RotorMassEccentricity` derives centrifugal forcing from explicit eccentric mass, offset and the body's actual angular velocity. `CompliantRadialBearing` derives radial restoring/damping forces from displacement and velocity relative to a bearing axis. `RotationalViscousFriction` opposes angular motion and reports dissipated mechanical power. `HarmonicSampleHistory` measures frequency components from resolved histories rather than inventing harmonics.

This is deliberately not a lathe model or a parts catalogue. Physical Modeler/Parts may supply shaft, spindle, bearing, tool and assembly definitions; Physics owns the resulting motion and forces.

## Dev12: escaped fluid remains in the physical world

`ExternalFluidParcels.cls` promotes each `EscapedFluidParcel` produced by a breached vessel into an `ExternalFluidParcelState`. The initial external model is intentionally conservative and small: parcels have mass, volume, position, velocity and simulation time; gravity advances them; explicit planes can receive parcel momentum through contact events.

`EscapedFluidWorldBinding` admits each breach parcel once and exposes the system accounting invariant `initial vessel fluid mass = retained vessel mass + external parcel mass`.

This is not SPH, VOF, shallow-water or general CFD. Parcels do not yet merge, spread into puddles, break into droplets, generate pressure fields, re-enter vessels, or interact with moving fracture shards.

## Dev11: fracture-aware fluid containment

`FluidContainment.cls` bridges fracture evidence to the two-horizontal-axis free-surface solver without pretending to be general CFD. `FluidContainmentBoundary2D` is the authority for whether the rectangular vessel is closed, breached or outside the supported topology. `FractureContainmentBinding2D` maps an explicitly identified structural link to an explicitly qualified wall opening; unrelated fractures do not leak.

For an active breach, `BreachedFreeSurfaceVessel2D` uses the local resolved liquid depth and the explicit opening geometry with `Q = Cd A_sub sqrt(2 g h)`. `Cd` is mandatory qualification data. Removed liquid is conserved as `EscapedFluidParcel` evidence rather than disappearing. Retained volume, mass and mean depth update immediately and therefore feed subsequent free-surface load/centre-of-mass calculations.

The first release deliberately stops at a fragmented containment boundary. It does not yet solve moving shard boundaries, external puddles, jets impacting geometry, re-entry, SPH/VOF CFD or fracture-created opening geometry automatically.

## Authority split

- **ooRexx Maths v0.8** — vectors, quaternions, transforms, rays and mathematical conventions.
- **ooRexx Units v0.1-dev4** — dimensions, units, quantities, canonicalisation and conversion proof.
- **Physics World** — physical body identity, pose, media, contact, structural/fluid state and solver interaction.
- **Rexx-tronics / Audio / other consumers** — domain state outside Physics; they consume typed Physics observations rather than becoming Physics dependencies.

Physics exports no `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` or Physics-local `SI` facade.

## Dev10: two-axis free-surface slosh merged into the current Physics line

`FreeSurfaceFluids2D.cls` merges the parallel slosh work into the current dev9 Physics authority rather than maintaining a competing Physics branch. It retains dev9 driven acoustics and thermal work unchanged and adds a conservative two-horizontal-axis shallow-water solver for rectangular prismatic tanks.

The vessel-local state is resolved per cell as liquid depth `h`, longitudinal discharge `qx = h u`, and lateral discharge `qz = h w`; local Y remains the tank up axis. X and Z Rusanov fluxes, reflecting walls on all four sides and a genuinely two-dimensional CFL bound evolve the free surface under simultaneous longitudinal and lateral effective gravity.

The model exposes conserved volume/mass, the resolved free surface, moving three-dimensional liquid centre of mass, two-axis relative momentum, kinetic/potential energy, X/Z shallow-water natural periods and a four-wall hydrostatic vessel-load report. `FreeSurfaceVesselCoupling2D` projects that state through the existing authoritative rigid-body pose and supports explicit kinematic forcing plus staggered before/after mechanics coupling.

The existing fail-closed boundaries are retained: no dry fronts, rim crossing/spill, non-positive floor-normal effective gravity, breaking/overturning waves or timesteps beyond the current CFL bound.

## Dev9: a driven diaphragm can now make sound

`DrivenAcoustics.cls` closes the continuous mechanics -> acoustics path that dev8 intentionally left open. `RigidRadiatingPatch` observes the actual velocity of a finite patch on an existing `RigidBodyState` after ordinary Mechanics has applied electromechanical force, springs, damping, contacts and any other loads. Successive observations derive physical normal acceleration; the acoustic coupling uses the compact-volume relation `Q=A v_n`, `dQ/dt=A a_n`, and retarded propagation `p=rho/(4*pi*r) dQ/dt(t-r/c)`.

There is no current-to-sound gain. Electrical current may drive a transducer, the transducer moves a body, and only that resolved body motion becomes acoustic radiation. `ContinuousMechanicalAcousticRenderer` returns the existing `AcousticSampleBuffer` in pascals for Audio/DSP consumers. Direct-path surface transmission and spatial acoustic media are honoured. The current model is explicitly a compact monopole-equivalent patch; full piston directivity, baffle diffraction and broadband frequency-dependent propagation remain future work.

## Dev9: dissipated watts can now become temperature

`Thermal.cls` adds first lumped thermal state without claiming a continuum heat-equation solver. A `ThermalNode` has absolute temperature and heat capacity; `ThermalPowerObservation` injects explicit signed thermal power with cause/source/evidence. `ThermalConductionPath`, `ThermalConvectionBoundary` and `ThermalRadiationBoundary` implement conductive, convective and grey-body radiative heat transfer. `ThermalMaterialProperties` provides specific heat, conductivity and optional emissivity, including clearly-labelled development approximations.

Physics deliberately does **not** reinterpret an electromechanical event's `unassignedTerminalPower` as heat. Rexx-tronics or another electrical authority must explicitly identify dissipated power and hand that evidence across as `ThermalPowerObservation`. This preserves the distinction among copper heat, stored magnetic energy, controller loss and unmodelled electrical state.


## Dev8: electrical state can now push the physical world

`Electromechanics.cls` adds a typed peer boundary for electrical-to-mechanical transduction without making Physics a circuit solver. An electrical peer supplies an `ElectricalDriveObservation` carrying Units-authoritative time/current and optional voltage. Physics applies the corresponding force or torque to the existing `RigidBodyState`.

The first transducers are deliberately reciprocal ideal models:

```text
linear:  F = K i        back EMF: e = K v_rel
rotary:  tau = K i      back EMF: e = K omega_rel
```

so the conversion power closes identically:

```text
F v_rel = e i
tau omega_rel = e i
```

There is no actuator `efficiencyFactor`. Winding resistance/inductance, switching and commutation remain electrical-authority state; springs, friction and damping remain mechanical-authority state. The actuation event reports terminal electrical power, reciprocal conversion power, mechanical power and any terminal power not assigned by the ideal transducer.

Linear transducers can apply equal-and-opposite reaction force to a physical stator body. Rotary transducers do the same for torque, preserving momentum exchange inside the modeled world.

The return path is explicit too: once mechanics moves the armature/rotor, the same transducer exposes a typed back-EMF observation for the electrical peer's next solve.

## Dev7: the liquid actually sloshes

`FreeSurfaceFluids.cls` adds `RectangularTankSlosh1D`, an explicit finite-volume solution of the one-dimensional nonlinear shallow-water equations in a rectangular vessel-fixed tank.

The solver state is not a scalar slosh coefficient. Every cell retains:

```text
liquid depth h(x,t)
depth-averaged discharge q(x,t) = h u
```

and evolves by mass and momentum conservation:

```text
∂h/∂t + ∂q/∂x = 0

∂q/∂t + ∂(q²/h + g_n h²/2)/∂x
    = h g_t - damping q
```

where `g_n` and `g_t` are the normal and longitudinal components of effective gravity in the vessel frame. Reflecting end walls are resolved by the numerical flux.

The implementation uses a local Lax-Friedrichs/Rusanov finite-volume flux with an explicit CFL guard. A requested timestep larger than the current stable bound fails closed rather than silently producing a pretty wave.

## Physical state exposed by the slosh model

The free-surface model exposes quantities derived from the resolved field:

- conserved volume and mass;
- left/right and per-cell liquid depths;
- depth-averaged velocity/discharge;
- local free-surface sample points;
- moving liquid centre of mass;
- relative fluid momentum;
- kinetic and gravitational potential energy;
- shallow-water fundamental period;
- minimum/maximum depth and surface amplitude;
- wall-pressure reaction force and torque on the vessel.

`FreeSurfaceSnapshot` is a retained typed observation of those quantities at a simulation time.

## Vessel coupling

`FreeSurfaceVesselCoupling` binds one slosh model to one existing `RigidBodyState`. The slosh grid remains vessel-local; its world position comes from the same authoritative vessel `PhysicalPose` used by mechanics, optics and acoustics.

For a known body acceleration:

```rexx
coupling~advanceKinematics(dt,bodyAccelerationWorld,gravityWorld)
```

computes effective gravity in the vessel frame and advances the fluid. The resulting wall/floor load can be submitted back to ordinary rigid mechanics:

```rexx
report=coupling~applyCurrentLoad
```

The report contains resolved pressure-load force/torque. There is no `sloshForceFactor`.

The class also provides `beforeMechanicsStep` / `afterMechanicsStep` for explicit staggered partitioned coupling to a `MechanicsSolver`. This is intentionally exposed as a coupling algorithm rather than pretending the fluid and rigid solvers are one monolithic integrator.

## Fail-closed free-surface boundary

Dev7 deliberately rejects conditions its model does not own:

- a cell approaching dry-front depth;
- a surface reaching the tank rim (spill/overflow);
- non-positive effective gravity normal to the floor (ballistic liquid/loss of bottom contact);
- a timestep exceeding the current CFL stability bound.

Those conditions require additional physics. They are not converted into `spillPercent`, `sloshingFactor`, or clamped cell values.

## Retained-liquid model remains useful

`ContainedFluidLoad` remains the cheaper physically narrower model for sealed/retained liquid that follows gross rigid-body motion. It is still appropriate when internal liquid motion is irrelevant.

Use `RectangularTankSlosh1D` when moving free-surface state matters.

## Existing mechanics/acoustics/optics retained

Dev7 is additive over the supplied dev6 baseline. It retains:

- finite support-point rigid contact and Coulomb friction;
- `RigidTumbleTracker`;
- retained-liquid mass/inertia and `VesselImpactExperiment`;
- mechanics -> structural vibration -> acoustic pressure;
- fluid statics/fields/pipe flow/pathlines/fully submerged body coupling;
- the Physics dev4 optical surface used by Rexx-tronics dev8.

## Example

`examples/sloshing_tank.rex` creates a 50 cm × 20 cm tank containing 15 L of development water, applies a short lateral acceleration and prints the evolving left/right surface height, liquid centre-of-mass shift and kinetic energy.

No Python fluid solver is used by the package.

## Running qualification

Put ooRexx 5.3.0 r13196 on `PATH`, then set:

```sh
export MATHS_REXX=/path/to/oorexx_maths_v0.8/rexx
export UNITS_REXX=/path/to/oorexx_units_v0.1-dev4/rexx
./run_tests.sh
```

The runner fails closed if Units is not v0.1-dev4 or if old Physics unit facades reappear.

## Honest dev10 boundary

The free-surface family now includes one- and two-horizontal-axis shallow-water models for rectangular prismatic tanks. It is not general CFD. Dev10 still does not claim magnetic-field or magnetic-circuit solution, nonlinear solenoid force/position curves, winding inductance, commutation, saturation, full loudspeaker piston directivity/baffle diffraction, continuum thermal conduction, phase change, natural convection derived from CFD, or a complete motor/controller model. Electrical topology remains the peer electrical authority.

The existing free-surface non-claims also remain: dry fronts, breaking/overturning waves, spill/mass loss, fully three-dimensional free surfaces, turbulence, cavitation, multiphase flow, entrained air, capillarity, automatic glass fracture, and fully implicit two-way fluid-structure coupling.

Those can be added as explicit solvers over the same world/body/material/Units/Maths authorities without replacing this API with correction factors.

### dev10.1 merged development line

This package reconciles the parallel dev10 2-D free-surface and brittle-fracture development lines. Both are present: `FreeSurfaceFluids2D.cls` retains the explicit 2-D slosh/vessel coupling work, while `Fracture.cls` and the fracture-enabled `Deformable.cls` provide evidence-backed brittle link failure and connected fragment topology. Neither solver is used as a hidden approximation for the other.

## Physical drum kit

See `DRUM_KIT.md` for the independent full-kit Physics peer of the guitar model.

### dev48 F11 execution/geometry extension

See `REAR_EXTERIOR.md` for the excavated rear parking/stairwell/terrain-step model and
`CLUSTER_ACOUSTIC_WORKFLOW.md` for distributed candidate-trajectory execution using the
existing Cluster object transport while keeping Physics objects cluster-unaware.


### dev50 F11 refinement evidence

See `REFINEMENT_EVIDENCE.md`. The named Room-F 0.25 m refinement plan creates 42 whole-trajectory Cluster tasks and `candidate-summary/3` adds compact pitch/cadence/power/delay/overlap/rear-path descriptors for explicit-tolerance reverse matching while leaving waveform data local.
