# Architecture — ooRexx Physics World v0.1-dev10

## Authorities

`ooRexx Maths v0.8` owns mathematical semantics. `ooRexx Units v0.1-dev4` owns dimensions/units/quantities. Physics World owns physical state and solver interaction.

```text
             Maths v0.8             Units v0.1-dev4
                  \                     /
                   \                   /
                    v                 v
                       PhysicalWorld
                   bodies / poses / regions
                            |
      +-----------+---------+----------+-----------+
      |           |                    |           |
   Optics     Mechanics             Acoustics    Fluids
                / | \                 ^   |       /       \
           rigid  | deformable         | pressure  fields  free surface
                  |                    |
          Electromechanics ----> DrivenAcoustics
          force / torque / back-EMF    actual patch motion
                  |
           electrical peer

                    Thermal
          explicit heat power / T state

       all physical motion uses the same body pose
```

No solver keeps a private copy of body position/orientation.


## Continuous driven acoustics

Dev9 does not map electrical current directly to pressure. `RigidRadiatingPatch` is bound to an existing `RigidBodyState` and samples the actual surface-point velocity after mechanics. Its normal acceleration drives compact-volume radiation. `ContinuousMechanicalAcousticRenderer` solves a retarded emission time for the moving patch before evaluating pressure at the receiver.

This preserves the chain:

```text
electrical observation -> electromechanical force -> mechanics
      -> actual diaphragm motion -> patch volume acceleration
      -> acoustic propagation -> microphone pressure -> Audio/DSP
```

The current direct-path renderer does not yet model finite-piston directivity, baffle diffraction, structural mode shapes across a flexible diaphragm or two-way acoustic loading back onto the structure.

## Thermal authority boundary

Thermal state is Physics-owned, but the identity of a heat source remains causal evidence from the producing domain. In particular:

```text
Rexx-tronics terminal/component power
        |
        | explicit identification of dissipated heat
        v
ThermalPowerObservation
        |
        v
ThermalNode -> conduction / convection / radiation -> temperature
```

`unassignedTerminalPower` from the ideal electromechanical transducer is **not** automatically thermalised. It may represent heat, stored field energy, switching/controller loss or omitted electrical state. Only an explicit heat observation enters Thermal.

The dev9 solver is lumped-capacitance explicit integration. It conserves equal/opposite conductive exchange across a link, but it is not a spatial heat-equation mesh and does not derive convection coefficients from fluid dynamics.


## Electromechanical authority boundary

Dev8 adds a reciprocal transduction boundary, not an electrical solver.

```text
Rexx-tronics / electrical peer
      |
      | ElectricalDriveObservation
      |  current [A], optional voltage [V], time/evidence
      v
ElectromechanicalTransducer
      |
      +--> force / torque --> RigidBodyState --> ordinary MechanicsSolver
      |
      `--> back EMF [V] -----------------------> next electrical solve
```

The linear ideal transducer uses one force constant `K` for both `F = K i` and `e = K v_rel`; the rotary model uses one torque constant for `tau = K i` and `e = K omega_rel`. Therefore conversion power is an invariant of the model rather than a calibration knob.

If a reaction body is supplied, equal-and-opposite force/torque is submitted to that body's ordinary mechanics accumulators. The stator frame may be a fixed `PhysicalPose` or live `PhysicalMount`, so actuator axes follow authoritative world geometry. No solver keeps an actuator-only copy of position/orientation.

Terminal electrical power is evidence only. Physics does not infer copper loss, winding magnetic energy or controller loss from the difference between terminal power and conversion power; it reports that difference as unassigned to the ideal transducer.

## Free-surface authority

Dev7 adds a resolved fluid state rather than a moving-centre heuristic.

`RectangularTankSlosh1D` owns only vessel-local liquid state:

```text
cell i:
    h_i  free-surface depth
    q_i  depth-averaged discharge h_i u_i
```

Tank world placement is not copied into the fluid solver. `FreeSurfaceVesselCoupling` projects the local grid through the authoritative `RigidBodyState~body~pose` when a world-space force/torque or observation is required.

### Governing model

The current solver is the one-dimensional nonlinear shallow-water system in the accelerating vessel frame:

```text
U = [h, q]
F(U) = [q, q^2/h + (g_n h^2)/2]
S(U) = [0, h g_t - lambda q]
```

`g_n` is effective gravity into the tank floor. `g_t` is effective gravity along the tank axis. `lambda` is an explicit optional linear damping rate.

Spatial update uses a conservative Rusanov flux. End walls use reflecting ghost states. The model therefore obtains surface motion from conservation-law evolution and wall boundary conditions, not from a prescribed sinusoid after initialisation.

### Numerical authority and failure

`maxStableTimeStep()` evaluates the current explicit CFL bound using `|u| + sqrt(g_n h)`. `step()` refuses a larger timestep.

The solver also refuses:

```text
h <= minimumDepth        -> dry-front physics required
max(h) >= tank height    -> spill/overflow physics required
g_n <= 0                 -> liquid has lost bottom contact / inverted
```

No state is clipped to make an unsupported solution continue.

## Resolved vessel load

The vessel-load projection uses the resolved end-wall hydrostatic pressure and instantaneous liquid centre of mass.

For left/right depths `hL`, `hR`:

```text
Fleft  = rho g_n width hL^2 / 2
Fright = rho g_n width hR^2 / 2
Fx     = Fright - Fleft
```

Pressure-resultant heights and the floor-normal load produce a local torque. `FreeSurfaceVesselLoadReport` retains those components before `FreeSurfaceVesselCoupling` transforms them through the body pose and submits them to `RigidBodyState`.

This is a first partitioned fluid/structure coupling, not an implicit monolithic FSI claim.

## Finite contact and retained liquid

The dev6 contact lane remains intact. Support-point hull contact uses translational + rotational effective mass and explicit Coulomb friction. `RigidTumbleTracker` integrates actual angular travel.

`ContainedFluidLoad` also remains intact for the physically distinct case where liquid is retained and internal free-surface motion is intentionally ignored.

```text
cheap retained load                   resolved free surface
-------------------                   ---------------------
ContainedFluidLoad                    RectangularTankSlosh1D
mass + inertia                        h(x,t), q(x,t)
        |                                      |
        +----------- vessel ------------------+
                            |
                    RigidBodyState / pose
```

## Shared spatial media

A `PhysicalMediumRegion` may carry optical, acoustic and fluid media at the same geometry. Queries remain:

- `mediumAt(point)`;
- `acousticMediumAt(point)`;
- `fluidMediumAt(point)`.

Changing world occupancy changes relevant solvers without an `underwaterMode` flag.

## Rexx-tronics consumer boundary

Rexx-tronics remains electrical authority. Physics dev7 preserves the documented dev4 objects (`PhysicalWorld`, `PhysicalPose`, `OpticalBeamProbe`, `OpticalBeamReading`, `Photometry`, `OpticalSensor`) used by Rexx-tronics dev8.

## Current non-claims

Dev9 does not provide general CFD, 2-D/3-D free-surface flow, spill/mass loss, dry fronts, breaking waves, turbulence, cavitation, multiphase flow, capillary/contact-line physics, automatic rigid-glass fracture, automatic continuum eigenmode derivation or fully implicit two-way fluid-structure/acoustic loading. The electromechanical lane also does not provide magnetic-field solution, nonlinear solenoid reluctance/force geometry, winding inductive state, saturation, commutation or controller electronics. Continuous acoustic radiation is presently a compact monopole-equivalent patch with direct-path propagation, not a finite-piston/baffle/diffraction or two-way radiation-loading solver. Thermal state is lumped; continuum heat conduction, phase change and CFD-derived convection remain future work. Field-level electromagnetics, granular mechanics and combustion/blast remain absent solver families.


## Dev10 two-axis free-surface authority

`RectangularTankSlosh2D` is merged beside the existing one-axis model and retains the same ownership rule: fluid owns vessel-local free-surface state; the vessel owns world pose.

```text
cell (i,j):
    h    depth
    qx   h*u longitudinal discharge
    qz   h*w lateral discharge
```

The conservative state is `U=[h,qx,qz]`. X and Z Rusanov fluxes include hydrostatic pressure `g_n h^2/2`; source terms are `h g_x`, `h g_z` and explicit linear momentum damping. Reflecting ghost states reverse only the normal discharge at each wall.

The explicit stability bound is genuinely two-dimensional:

```text
dt <= CFL / ((|u|+sqrt(g_n h))/dx + (|w|+sqrt(g_n h))/dz)
```

Four-wall hydrostatic pressure resultants and floor-normal load are integrated into one local force/torque report. `FreeSurfaceVesselCoupling2D` uses the existing body `PhysicalPose` to project the result into world mechanics. No second body position/orientation is maintained.

## dev10.1 merged fracture boundary

The dev10.1 merge keeps the 2-D free-surface solver and brittle fracture as peer physical domains. `Fracture.cls` consumes deformable-link constitutive state; it does not replace fluid, contact, acoustic, thermal, or electrical authority. A failed link changes deformable connectivity and can be projected into fragment topology. Released elastic energy is partitioned only where the fracture law has evidence (for example minimum surface-creation energy); unresolved energy remains explicit and is not guessed into heat or sound.

Current fracture non-claims remain: no arbitrary continuum crack path, crack-tip stress-intensity solver, remeshing, sharp-shard collision hull generation, dynamic fracture-wave redistribution, or automatic fracture acoustics.


## Fracture → containment → free-surface coupling (dev11)

Containment is a separate authority from fracture and fluid state. Fracture says which structural connection failed; an explicit binding says whether that failure opens a wet boundary; containment says which hydraulic openings exist; the free-surface solver owns retained liquid state.

The supported ordering is mechanics/deformation → fracture → containment update → free-surface evolution/discharge → updated retained fluid load. Discharged liquid is represented by retained `EscapedFluidParcel` records, preserving mass and provenance for a future external-fluid solver.

A disconnected or moving shard boundary is not approximated as the old rectangular tank. `FRAGMENTED` containment raises a fail-closed condition.


## External fluid after containment loss (dev12)

Escaped liquid is not deleted at the containment boundary. `EscapedFluidParcel` remains the authoritative release record and is promoted into a live `ExternalFluidParcelState`. The first world model advances those parcels ballistically and can exchange normal momentum with explicit planes.

This provides a conservative handoff point for later SPH/VOF/shallow-water or fragment-fluid solvers without forcing such semantics into the current free-surface solver. Retained-vessel and external-fluid masses remain separately observable.


## Rotating machinery boundary (dev13)

Parts/Physical Modeler own reusable part definitions, manufacturing geometry and assembly intent. Physics receives mass/inertia, pose, angular state, eccentric mass/offset, support compliance/damping and friction data and owns the resulting forces and motion. Spectral observations consume resolved histories; they do not create motion.

The dev13 model is a reusable foundation for spindles, wheels, fans, rotors, pumps and similar assemblies. Gear mesh, rolling-element bearing geometry, shaft continuum modes, cutting contact and material removal remain future layers.


## Physical Modeler/manufacturing integration boundary (dev14)

Physical Manufacturing projects finite machine masses, geometry and process state. Parts owns reusable component identity/defaults. Materials owns reference material properties. Physics consumes explicit physical projections such as mass/inertia, stiffness, damping, friction and force and returns motion, vibration, dissipation and spectral evidence. It does not mutate manufacturing/CAD truth.

The current modal layer is reduced-order linear mechanics. It is not a beam/FE continuum solver and does not infer modal properties from arbitrary CAD solids.


## Distributed-source observation boundary (dev15)

Physics may aggregate explicitly incoherent RMS source contributions statistically. Coherent waveform propagation remains a different operation and must retain phase/time-of-flight information. The 83,500-person crowd case therefore cannot be implemented as `83500 * onePersonPressure`.

Game meaning, supporter affiliation, recognition and reaction are world/cognition authority, not Physics. Physics owns physical observation availability, source emission once specified, propagation and receiver evidence.


## Aerodynamics boundary (dev16)

Parts may define object identity, construction, dimensions, inflation state and the requirement for aerodynamic behaviour. Materials may define constituent physical properties. Physics owns resolved aerodynamic force/torque. The current axial model is reduced-order and orientation-sensitive; it is not CFD, boundary-layer resolution or a certified rugby-ball coefficient database.


## Flight experiment boundary (dev17)

Flight is composition, not a new mechanics authority. Aerodynamic forces/torques are applied to `RigidBodyState`, then Mechanics advances translational and rotational state. Parts supplies identity/dimensions/mass; Physics supplies behaviour; coefficient truth remains an explicit caller/model input. The current rugby inertia is a prolate-body reference approximation and the collision hull remains simplified.

## Aircraft operations boundary (dev18)
Physics owns resolved thrust/fuel-flow evidence and wheel/tyre forces, slip, energy dissipation and wear-state evolution. Aircraft, engine and tyre catalogue identity belongs to Parts; constituent properties belong to Materials. Flylo operations/maintenance owns fuel-uplift and tyre-order decisions. Physics does not make procurement decisions.

## Landing dynamics boundary (dev19)
Physics owns touchdown vertical energy, strut force/damping, normal load and tyre contact evidence. Parts owns landing-gear/tyre identity and geometry; Materials owns constituent properties. Aircraft maintenance owns inspection/damage/replace/order decisions. The current model is a reduced-order single supported-mass strut/wheel element, not a flexible-airframe or oleo-pneumatic certification model.

## Multi-station aircraft ground boundary (dev20)
Physics composes multiple independently modelled landing-gear/tyre stations and resolves their physical observations into ground-roll resistance. Load distribution is currently an explicit caller projection; dynamic pitch/load transfer, brake hydraulics/anti-skid, runway roughness and flexible-airframe response are not yet inferred. Flylo remains operational/maintenance authority.

## Ground-load authority (dev21)
Physics can now derive longitudinal nose/main load distribution from explicit aircraft geometry and acceleration instead of requiring a configured percentage. This is a quasi-static longitudinal equilibrium model. It does not yet solve pitch inertia, individual left/right lateral transfer, oleo gas thermodynamics, runway roughness or flexible-airframe response. Those must remain explicit future models.

## Dynamic ground-run composition (dev22)
The longitudinal normal-load percentage is no longer an aircraft configuration constant in the new experiment: it emerges from explicit geometry and acceleration. Left/right division within an axle remains an explicit projection until lateral acceleration, track width and COM lateral/vertical geometry are modelled. Supplied longitudinal acceleration remains the kinematic authority for each step; tyre resistance is reported independently rather than being double-counted into acceleration.

## Lateral ground-load authority (dev23)
Physics now has a separate lateral equilibrium primitive suitable for composing with dev21 longitudinal axle-load resolution and dev22 individual tyre histories. It deliberately remains separate until a combined experiment can state exactly which geometry/acceleration authority drives each axis. No crosswind force, steering law, anti-skid logic, or aircraft-specific track is invented.

## Aerodynamic data authority (dev24)
The earlier axial reduced-order model remains useful for generic bodies. dev24 adds a separate measured/computed-data seam suitable for aircraft and richer parts: coefficient data are supplied explicitly and evaluated only inside their qualified domain. Parts may own geometry/reference dimensions and references to aerodynamic datasets; Physics owns evaluation and resulting force/moment evidence. Research-factory candidate data are not automatically trusted as certified physical properties.

## Parallel aerodynamic/load development (dev25)
Aerodynamic fidelity and landing/ground loads advance together. The aerodynamic surface is an evaluation mechanism, not a source of aircraft coefficients. Ground loads remain quasi-static equilibrium evidence and do not yet include pitch/roll inertia or aerodynamic unloading. The next coupling boundary is explicit: resolved aerodynamic vertical force/moments can alter the rigid-body/contact state, from which gear loads should emerge rather than being subtracted through an ad-hoc lift factor.

## Aerodynamics -> contact-load bridge (dev26)
Aerodynamic force is no longer merely flight evidence beside an unrelated `m*g` ground model. dev26 establishes an explicit equilibrium boundary: upward aerodynamic force reduces total ground reaction and aerodynamic pitch moment redistributes the remaining reaction between axles. It deliberately does not subtract an `aero unloading factor`. Dynamic pitch inertia, strut transients and rigid-body contact remain the next fidelity step.

## Static vs dynamic lateral loading (dev27)
Physics now represents two distinct mechanisms rather than conflating them: dev27 static lateral CG/payload offset and dev23 inertial lateral load transfer. A centred fluid mass may contribute to static weight with zero roll moment; when fluid motion is later coupled, its current physical centroid must replace—not duplicate—the rigid projection. The same contained mass must never be counted simultaneously as fixed ballast and dynamic slosh mass.

## Static payload + dynamic contained fluid (dev28)
The Claude harmonic-slosh demo exposed a missing composition boundary. dev28 makes that boundary explicit. Fluid weight/mass belongs once in the aircraft static mass projection. Free-surface dynamics contributes its computed dynamic torque; it must not introduce a second copy of the contained mass. This remains lateral equilibrium composition, not full aircraft roll dynamics.

## CFL collapse diagnosis (dev29)
The sustained undamped resonant slosh demo raised a specific hypothesis: a trough approaches the solver minimum depth while depth-integrated momentum remains finite, causing q/h velocity to dominate the CFL rate. dev29 instruments that mechanism without changing it. This distinguishes caller timestep mismatch from shallow-water model-domain exhaustion. No amplitude cap is introduced: an arbitrary cap would conceal the validity boundary. Wetting/drying and breaking-wave physics remain explicitly outside the current solver.

## Package-wide freeze spine (dev30)
Freeze authority belongs to `PhysicalWorld`. A checkpoint is a coherent simulation-instant snapshot: world time, authoritative body poses, and all registered future-determining solver state. Stateful solvers participate through explicit identity/schema/export/restore contracts; arbitrary ooRexx object serialization is not the architecture. Restore validates the complete participant inventory before changing state. Immutable physical truth should eventually be represented by identity/hash in a durable checkpoint manifest, while derived caches should be reconstructed. dev30 intentionally separates this world checkpoint from any later replay/event journal.

## Forward acoustic oracle (dev31)
`AcousticImpulseResponseSolver` is intentionally ignorant of F11, room labels, observed delays and localisation hypotheses. It consumes physical source position/emission, receiver positions, world medium, finite surfaces, spectral material responses and explicit diffraction geometry. It emits forward predictions. Audio/localisation consumers compare observations against those predictions independently.

An arrival is evidence-bearing geometry:
source -> zero or more transmission vertices / one reflection or diffraction vertex -> receiver,
with path length, delay and a complex pressure phasor for every requested frequency band.

Current bounded path family: direct/transmitted, one finite specular reflection, and one explicit diffraction point. Higher-order reflection/diffraction combinations and automatic UTD/knife-edge coefficient derivation are non-claims in dev31.

## Shared live freeze authority (dev31)
Physics can adapt its continuation participants to the common `oorexx_journal_pointed_state_v0.1` package. `PhysicsWorldJournal(world, sharedController, prefix)` accepts an externally owned `StateOfNationController`, allowing Physics and Rexx-tronics to inhabit one coherent State-of-the-Nation checkpoint. Durable `PhysicalWorldCheckpoint` remains a separate persistence boundary.

## Early-path expansion boundary (dev38)
The forward oracle now has a separate bounded early-path expansion rather than silently turning the base solver into an open-ended ray tracer. This matters for F11-like indoor geometry: a physically useful secondary can require two doorway/corner interactions, or one finite reflection plus one corner interaction, while the direct path remains blocked or heavily transmitted.

The dev38 order-2 families are solved from supplied geometry. Diffraction points remain explicit physical/evidence inputs; finite reflection points come from each surface's reflection protocol. Every leg is rechecked for medium consistency and spectral surface transmission, and the complete path must fall inside the caller's arrival window.

Not yet claimed: two-specular-reflection image-source chains, arbitrary N-order paths, automatic UTD coefficient derivation, diffuse late reverberation, or a statistical room tail.

## Electric-guitar proof boundary (dev39)
The guitar demo is useful precisely because it crosses several independent authorities without permitting any one library to fake the rest:

ASCII tab / performance event
 -> Physics vibrating string state
 -> Physics magnetic flux at pickup geometry
 -> Rexx-tronics Faraday transduction and pickup winding
 -> Rexx-tronics passive/active electrical network
 -> Physics electromechanical loudspeaker motion
 -> Physics finite radiating patch / acoustic propagation
 -> Physics pressure samples
 -> Audio analysis/rendering

`GuitarStringMagneticFluxProbe` therefore does not expose a volts-per-string-velocity synthesizer constant. Its reduced-order approximation is a local linearization `Phi = Phi0 + (dPhi/dy)y`; the gradient is explicit evidence belonging to a particular magnet/string geometry or calibration. Physics calculates `y(t)` and the resulting flux observation. Rexx-tronics applies `-N dPhi/dt`.

This is intentionally short of a full 3-D magnetostatic/ferromagnetic field solver. The public observation seam allows such a solver to replace the linearized field model later without moving Faraday/winding authority into Physics.

## Guitar dual-observation proof (dev40)
A played string now has two independent consequences from the same Physics string state:

string excitation
  +-> displacement at pickup -> magnetic flux -> Rexx-tronics Faraday/circuit path
  `-> modal string energy -> bridge coupling -> guitar-body modes -> mechanical/acoustic path

`GuitarBridgeCoupling` transfers an explicit fraction of initial string modal energy and partitions only that budget among supplied body modes. The transfer fraction and body-mode properties are model/calibration inputs, not universal guitar constants. This is a reduced-order bridge/body model; dev40 does not yet solve a continuous neck/body finite-element structure or two-way body-to-string feedback.

This is deliberately useful as a proof: Audio can eventually compare the electrically amplified path and the quieter unplugged mechanical-radiation path produced by the same performance event.

## Reciprocal guitar boundary (dev41)
Dev40 proved two observations from one string event but its bridge transfer was one-way. Dev41 adds a separate reciprocal modal boundary. String and body modes retain their own mass, stiffness and damping; a boundary spring applies equal and opposite force to the summed string/body boundary displacement. This permits body motion to feed back into strings and permits an initially silent string to be excited through the shared body.

The implementation is intentionally reduced-order rather than a finite-element neck/body claim. Coupling stiffness, modal masses/frequencies/damping and retained mode count remain explicit physical/calibration evidence. The integrator is bounded explicit symplectic Euler and callers must select a time step appropriate to the highest retained mode. A future continuous structure solver can replace this participant without changing the higher-level guitar experiment.

## Guitar monitor feedback (dev43)
An unplayed string has zero intentional excitation, not permanently zero motion. Monitor-speaker pressure can excite every string and the body before magnetic transduction. This is physical feedback, not output-side synthetic reverb. The driver consumes pressure/path evidence from the acoustic solver and applies external work to the shared multi-string mechanical instrument.

## Maths v0.10 acceleration boundary (dev44)
Physics now distinguishes two workloads.

Closed-form modal rendering is delegated to Maths v0.10:
Physics string/material/topology -> modal amplitudes/frequencies/decays/phases -> `MathDampedOscillatorBank` -> sampled displacement/flux.

Reciprocal time-stepped mechanics remains in Physics for now:
M*x'' + C*x' + K*x = f.

Physics must not create a private competing generic integrator merely to obtain speed. The intended next seam is the proposed Maths second-order linear-system/state API. Once Maths publishes it, Physics can assemble M/C/K/force vectors from physical topology and delegate the numerical step while retaining force, energy and causality interpretation.

The native path is optional and precision-bounded: BINARY64/NUMPY may accelerate; DECIMAL/PURE remains authoritative for qualification and independent comparison.

## Coupled dynamics acceleration (dev45)
Physics owns the guitar topology and constructs M, C and K from the existing six string courses, string modal masses/stiffness/damping, bridge participation, nut impedance and body modes. Maths v0.11 owns propagation of the resulting generic constant-coefficient second-order system. `SYMPLECTIC_EULER` is retained so acceleration does not silently change the existing Physics integration scheme.

`GuitarMathsDynamicsProjection~advanceInstrument` writes the terminal Maths state back into the original Physics oscillator objects, advances simulation time, and journals the Maths evidence. This keeps downstream pickup, body, acoustic and checkpoint code on the same physical objects rather than creating a parallel accelerated guitar representation.

External forces remain an explicit Maths force argument. The next integration is to assemble monitor-speaker acoustic pressure into the force history so the accelerated system includes the dev43 acoustic-feedback loop rather than falling back to scalar per-step forcing.

## Peer physical instruments (dev46)

The guitar and drum kit are peer Physics participants. `GuitarInstrumentMechanics` retains guitar authority; `DrumKitPhysics` retains drum/cymbal authority. They may share `PhysicalWorld`, room acoustics and the package freeze/journal boundary, but neither instrument owns the other. Acoustic pressure may be fed back into either instrument for sympathetic mechanical excitation.

## Guitar acoustic block continuation (dev46.8)
The monitor path is now block-capable:
speaker/room pressure samples -> Physics pressure-to-force projection -> `(steps+1) x DOF` force history -> Maths v0.14 continuation -> authoritative guitar modal state -> pickup.
The scalar dev43 driver remains a qualification/simple-step path. The block path does not synthesize reverb and does not bypass strings/body mechanics.
