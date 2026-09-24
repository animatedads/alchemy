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
