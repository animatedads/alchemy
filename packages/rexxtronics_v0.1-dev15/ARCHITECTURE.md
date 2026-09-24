# Rexx-tronics architecture — v0.1-dev15

## Authority boundaries

1. **Simulation time is authoritative for circuit behaviour.** Wall-clock duration is performance metadata only.
2. **Circuit topology is explicit.** Components own pins; nets connect pins; no behavioural layer may bypass the net model to manufacture a result.
3. **Electrical solvers are authoritative for voltage/current/power.** Instruments observe solver/event state; they do not create electrical truth.
4. **Instrument acquisition is independent.** A virtual instrument may undersample, alias, quantize or otherwise fail to observe a real simulated event without altering that event.
5. **ooRexx Units v0.1-dev4 is authoritative for physical dimensions, conversions and quantity metadata.** Rexx-tronics normalizes typed values at solver boundaries and does not own a private unit catalogue.
6. **Physical-world solvers are separate authorities.** Rexx-tronics owns electronics. Physics owns optics/mechanics/acoustics/thermal/environmental propagation. Their interchange uses the same Units contract and simulation-time coordinate.
7. **Live hardware is a boundary, not another clock.** Real devices either synchronize simulation to real time or enter through explicit capture/replay.

## Quantity boundary

```text
public API
   |
   | UnitQuantity / supported textual quantity / documented legacy scalar
   v
RexxTronicsUnits
   |
   | validate physical dimension
   | preserve Units metadata where interchange requires it
   | convert to canonical SI scalar
   v
numerical electrical kernel
   |
   | canonical voltage/current/etc.
   v
quantity-valued public result
```

The matrix/integration kernels deliberately remain numeric. Type/dimension validation occurs before values enter them; public results reconstruct typed quantities afterward.

Units dev2's stable metadata schema is the preferred serialization/interchange form when quantity source/display provenance must survive a boundary.

## Solver layers

```text
Circuit / Component / Pin / Net
             |
      component laws
             |
      +------+------+
      |             |
   DC MNA        transient MNA
      |             |
 nonlinear       nonlinear
 region solve    region solve
      |             |
      |       integration models
              capacitor BE
              inductor BE
      |             |
      +------+------+
             |
    authoritative electrical state
             |
   +---------+------------------+
   |                            |
instruments                observers/adapters
                                |
                      protocols / Physics / hardware
```

## Time and Units

Simulation time is an integer number of picoseconds. Public time-facing APIs accept Units quantities, and dev5 additionally accepts textual time quantities supported by the Units parser. A time that cannot resolve exactly to a whole picosecond is rejected rather than rounded.

A simulated 500 Hz oscillator therefore has a 2 ms period regardless of host runtime speed. Sampling rate belongs to an instrument, not to circuit truth.


## Nonlinear operating regions

The current semiconductor kernel is deliberately deterministic and inspectable rather than a hidden SPICE dependency. A nonlinear component stamps one linearized operating region, the solver evaluates the resulting voltage state, and the component may request another matrix build when its region changes. Iteration is bounded and fails closed if no stable region is reached.

For the initial diode family the regions are `OFF`, `FORWARD`, and (when configured) `REVERSE` breakdown. The piecewise law is parameterized by forward knee, on resistance, off resistance, reverse breakdown and reverse dynamic resistance. Exact part-number definitions can therefore replace generic parameters later without changing solver architecture.

Transient nonlinear iteration occurs before dynamic device state is committed, so a capacitor or inductor history term is advanced once per accepted simulation-time step rather than once per nonlinear trial.

## Transient integration

The current transient solver uses fixed-step backward Euler.

For capacitance `C`, step `dt` and previous capacitor voltage `Vprev`, the capacitor companion model is a conductance `G=C/dt` plus a history current source.

For inductance `L`, step `dt` and previous current `Iprev`, the inductor companion model is a conductance `G=dt/L` plus history current `Iprev`, equivalent to:

```text
i[n] = i[n-1] + (dt/L) * v[n]
```

Discrete events such as switch operations are scheduled on the same `SimulationClock` and applied before the electrical solve at that simulation-time step.

## Controls

`VariableResistor` is a two-terminal adjustable resistance with configured bounds.

`Potentiometer` is three-terminal. Position 0 places the wiper at B; position 1 places it at A. Positions may be supplied as legacy 0..1 numerics or shared dimensionless/percent quantities.

`Switch` has a low closed resistance and a very high open resistance in the current linear model. Its topology peer relationship is absent while open and present while closed.

## Physical-world coupling

The Physics adapter must preserve this causal chain:

```text
Electrical cause
 -> UnitQuantity physical emission at simulation time
 -> Physics propagation/material interaction
 -> UnitQuantity physical observation at simulation time
 -> sensor transfer characteristic
 -> electrical consequence
```

Every exchange must preserve source identity, simulation timestamp and cause/provenance. No coupling may substitute wall-clock timestamps for simulation timestamps.


## Environmental observation boundary (dev7)

Rexx-tronics does not solve optical propagation. Physics or another environmental source emits typed observations at authoritative simulation-time coordinates. Sensor models translate those observations into electrical state. The initial `PhotoResistor` contract accepts illuminance through a data-driven `LightResistanceCurve`; out-of-range behaviour fails closed unless a part model explicitly chooses clamping. Source/cause and simulation time are retained so an electrical state can be traced back through the physical-world observation that caused it.

```text
Rexx-tronics emitter state
        -> Physics propagation
        -> IlluminanceObservation(time,cause,source)
        -> PhotoResistor response curve
        -> electrical resistance
        -> DC/transient solve
```

The response curve belongs to the exact part definition. It is not a global CdS approximation. Richer future sensors may consume irradiance spectra or other physical quantities without changing the circuit solver.


## Executable Physics peer boundary (dev9)

The previous environmental contract is now backed by an optional concrete adapter for the supplied Physics World dev4 API.

Authority remains split:

```text
Rexx-tronics                         Physics World
-------------                        -------------
electrical topology/state            body identity / pose
component electrical power           optical media
transducer evidence curves    --->   reflection/refraction/occlusion
sensor electrical response    <---   photometric observation/evidence
simulation time                       physical geometry/material truth
```

A `PhotometricLamp` is deliberately only an electrical-to-photometric transducer.  It does not ray trace.  A `PhotoResistor` is deliberately only a photometric-to-electrical transducer.  It does not solve optics.

`PhysicsBeamIlluminanceAdapter` samples the Physics world **when the simulation-time event executes**, not when the event is scheduled.  This preserves the possibility that mechanics has moved a body, a mirror, prism, source or sensor in the meantime.

The accepted observation preserves:

- simulation time;
- causal description;
- emitting source object;
- Physics `OpticalBeamReading`;
- central-ray transmission;
- exact rectangular-solid-angle baseline illuminance;
- received illuminance;
- source/sensor distance and aperture dimensions;
- wavelength.

Thus an electrical result can retain a provenance path back through the optical solve rather than merely recording a naked lux scalar.

### Current optical projection scope

Physics dev4's `OpticalBeamProbe` is a central-ray geometric probe.  The dev9 adapter multiplies its material/geometric transmission by Physics' exact isotropic rectangular-aperture photometry baseline.  This is appropriate for the present explicit contract but is not silently promoted to a full aperture-integrated, spectral or extended-source solution.  Such a future Physics result can cross the same typed observation boundary without changing Rexx-tronics' electrical kernel.

## Scheduler integrity (dev9)

The simulation event queue is compacted after each dispatch.  The previous use
of `Array~remove()` could leave sparse indexes and hide later events; the defect
was exposed as soon as Physics geometry insertion and a later optical sample
were scheduled on one clock.  Ordering is now explicitly `(simulation time,
sequence)` and covered by a three-event regression including equal timestamps.


## Acoustic round trip

The authority boundary is:

```text
mechanical/contact state (Physics)
        -> structural vibration (Physics)
        -> acoustic pressure vs simulation time (Physics)
        -> microphone pressure-to-voltage transfer (Rexx-tronics)
        -> electrical circuit/transient MNA (Rexx-tronics)
        -> virtual instrument acquisition (Rexx-tronics)
```

Pressure samples never become wall-clock samples.  `AcousticSampleBuffer.startTime` and sample rate are projected into the Rexx-tronics simulation-time coordinate.  A host may compute the sequence faster or slower than real time without changing the physical frequency observed by the virtual oscilloscope.


## Reciprocal electromechanical coupling (dev11)

The electrical/mechanical boundary is reciprocal rather than a one-way actuator callback. Rexx-tronics owns circuit topology and winding electrical state; Physics owns motion and ideal conversion.

```text
      Rexx-tronics                         Physics World dev9
      -------------                        ------------------
      terminal voltage/current             rigid-body pose/velocity
      winding R/L                    --->  F=K*i or tau=K*i
      source/switch state             <---  e=K*v or e=K*omega
      copper/storage power                 mechanical/conversion power
```

The ideal converter is represented electrically by `PhysicsBackEmfSource`. This keeps back EMF inside the same MNA network as the supply and winding resistance. The resulting current becomes a typed `ElectricalDriveObservation` for Physics, and Physics' actuation event returns the power evidence for cross-domain closure.

The dev11 fixed-step coupler is a deliberately exposed partition algorithm. It does not blur two independent solvers into a false monolithic authority, and it does not reset/approximate winding inductance while claiming otherwise. Persistent electrical transient state is the next coupling boundary required for full motor/voice-coil R-L dynamics.

## Persistent multi-domain timestep state (dev12)

Dynamic electrical storage may not be reconstructed from a fresh DC solve at every Physics partition. `TransientSolver` therefore has a persistent mode: capacitor voltage, inductor current, nonlinear operating state, accumulated transient points and simulation-clock position survive each `step()` call.

The Physics electromechanical coupler uses this persistent solver directly. A partition is intentionally first-order staggered:

```text
back EMF at t
   -> electrical BE solve to t+dt (R/L/C history retained)
   -> converter current at t+dt
   -> Physics force/torque over the partition
   -> mechanics reaches t+dt
   -> reciprocal back EMF at t+dt
   -> next electrical partition
```

This closes the dev11 limitation where winding inductance could exist in the circuit but was not valid across repeated quasi-static electromechanical partitions. It does not claim an iterated fully implicit solve; tighter coupling is obtained by reducing `dt` until a future rollback/corrector interface exists.

## Regulator control loops and output networks (dev12)

Regulators are dynamic electrical systems, not labels attached to ideal voltage
sources.  `FeedbackLinearRegulator` therefore contributes a finite conductance
between `VIN` and `VOUT` and advances explicit internal control-loop state from
the solved output error.

```text
VIN -- finite pass element -- VOUT -- load
                           |
                           +-- COUT / ESR / wiring / probes / anything else

VOUT - GND -> error -> pole 1 -> pole 2 -> pole 3 -> pass conductance
```

This keeps the output capacitor, its stored charge, its current and every scope
measurement inside the ordinary Rexx-tronics transient network.  The regulator
never asks "is there a capacitor?" and there is no rule saying `COUT=0` means
"unstable".  Stability is an emergent property of the configured loop and the
actual network.

The qualification deliberately proves both sides:

- one explicit high-loop-gain profile oscillates after a load step with no
  output capacitor and becomes well damped when a 100 uF capacitor is fitted;
- the same topology with a lower control gain remains settled with `COUT=0`.

The generic profile is test data.  A real component definition should obtain
control gain, poles, pass limits, recommended output network and tolerance
conditions from the exact manufacturer's data/evidence.  More sophisticated
future regulator models may add ESR zeros, current limiting, dropout state,
reference noise, thermal shutdown and device-specific compensation without
changing the electrical authority boundary.

## Physics dev9 thermal and driven-acoustic peers (dev12)

Physics World dev9 remains authoritative for its new `Thermal.cls` and
`DrivenAcoustics.cls` surfaces.  Rexx-tronics consumes them only through
explicit physical evidence:

```text
electrical solved positive dissipation
    -> explicit ThermalPowerObservation
    -> Physics ThermalNode / thermal solver
    -> temperature observation
    -> temperature-dependent electrical component on next partition
```

and:

```text
electrical winding current
    -> Physics reciprocal force
    -> resolved diaphragm mechanics
    -> retained radiating-patch motion
    -> Physics acoustic pressure
    -> Rexx-tronics microphone electrical source
    -> scope
```

There is no automatic conversion of unexplained terminal power into heat and no
electrical-current-to-sound-pressure gain shortcut.

## Structural fracture -> electrical continuity

Physics World dev10 owns deformation, contact, brittle criteria, fracture energy and post-fracture connected components. Rexx-tronics does not duplicate those laws.

```text
Physics DeformableLink
      |
      | intact / broken + FractureEvent evidence
      v
PhysicsFractureConductor
      |
      | electrical conductance/path state
      v
Rexx-tronics MNA / transient solver
```

The boundary is intentionally one-way in dev13. Mechanical fracture can open a circuit; electrical heating or electromagnetic loading does not fracture material unless a separate explicit coupling supplies that physical cause. A broken conductor is represented by an explicit high off-resistance for matrix conditioning, while graph-level internal path traversal reports the conductor as open.

`FractureElectricalCoupler` uses the existing persistent transient stepper. Each partition advances Physics first, captures fracture/contact evidence, then advances the electrical solution to the same endpoint. Both domains are checked against the shared authoritative simulation-time coordinate.
## 2-D free-surface / electrical-sensor boundary (dev14)

Physics World dev10.1 is authoritative for `RectangularTankSlosh2D`: depth/discharge fields, two-axis forcing, CFL safety, mass/energy state and vessel loads. Rexx-tronics may observe a selected Physics depth and pass it through an explicit electrical sensor calibration, but must not reproduce the shallow-water solve or infer a generic sensor law.

The current coupling is a deterministic staggered endpoint scheme on the shared simulation clock. It preserves persistent electrical reactive history; it is not a monolithic fluid/electrical integrator.

The same pattern is intended for future physical sensors: Physics supplies the measured physical quantity and provenance; an exact component definition supplies the transducer law; Rexx-tronics owns the resulting electrical pins/network.



## Controlled-source semiconductor boundary (dev15)

Compact active devices remain ordinary participants in the same MNA matrix as
passives and sources.  `DCStampContext~stampVCCS` is now the primitive for a
voltage-controlled current contribution.  The first consumer is the BJT model:

```text
base/emitter electrical state
        -> explicit BJT operating region
        -> controlled collector current or saturation branch
        -> same circuit MNA solution
```

This is not a separate digital/transistor solver and does not bypass electrical
topology.  NPN and PNP use one polarity-symmetric formulation, which is
qualified independently for cutoff, active gain, and saturation.

Seven-segment displays are also electrical devices, not presentation objects.
Each segment has its own solved diode/resistance branch, so display state is an
observation derived from circuit current.  This preserves the project-wide rule
that instruments and visual representations do not own an independent copy of
electrical truth.
