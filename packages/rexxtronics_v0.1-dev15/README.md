# Rexx-tronics v0.1-dev15

Executable ooRexx electronics modelling with explicit electrical topology,
simulation time, DC/transient solving, virtual instruments, shared Units, and
optional ooRexx Physics World coupling.

## Current authority split

- **Rexx-tronics** owns electrical/electronic topology, component transfer laws,
  circuit state, MNA/transient solving and electrical instruments.
- **ooRexx Units v0.1-dev4** owns units, dimensions, conversion and typed physical
  quantities.
- **ooRexx Maths v0.8** owns vector/matrix/quaternion/3-D semantics.
- **ooRexx Physics World v0.1-dev10.1** owns non-electrical world behaviour including
  geometry, optics, mechanics/contact dynamics, deformable/fracture topology, structural vibration, acoustics, fluids/free surfaces, and reciprocal electromechanical actuation.

No peer is reimplemented as a Rexx-tronics compatibility facade.

## Simulation time

Electrical and physical behaviour is defined against authoritative simulation
time, represented in Rexx-tronics as integer picoseconds. Wall-clock execution
speed does not change oscillator frequency, transient duration, Physics sample
time, or virtual-instrument acquisition.

A 500 Hz oscillator remains 500 Hz whether one simulated second requires three
minutes or 0.1 seconds of host computation.

## Electrical foundation

Implemented surfaces include:

- `Circuit`, `ElectricalNet`, `Pin`, explicit `GND`;
- topology validation and electrical path tracing;
- resistors, variable resistors and potentiometers;
- switches;
- capacitors and inductors;
- diode, Zener and LED piecewise-linear semiconductor models;
- explicit NPN/PNP piecewise-linear BJT models with cutoff, forward-active and saturation regions, solved through an MNA voltage-controlled-current-source primitive;
- electrically solved common-cathode/common-anode seven-segment displays with per-segment current/state and digit decoding;
- DC and step voltage sources, DC current sources;
- modified nodal analysis with nonlinear region iteration;
- fixed-step transient analysis using backward-Euler reactive companion models;
- virtual oscilloscope acquisition on simulation time;
- evidence-driven photoresistor and photometric-lamp physical boundaries;
- Maxitronix 500-in-1 source-backed fixtures now include Project 7 (Light Telegraph), both PNP/NPN schematics of Project 14 (Meet the Transistor), and Project 15 (Transistors as Switches / digit 8);
- Physics-backed ideal electromechanical converter sources with explicit back-EMF feedback;
- persistent multi-domain transient stepping with electrical C/L history;
- feedback linear-regulator control-loop models whose external output capacitors remain ordinary electrical components.
- Physics-backed brittle-fracture conductors whose electrical path opens only when the authoritative physical load path actually fractures;
- Physics dev10.1 2-D free-surface depth probes mapped through explicit calibrated electrical level transducers, with two-channel virtual-scope qualification;
- 50-digit MNA stamp accumulation at solver boundaries so high-precision shared Units quantities are not silently rounded by method-local defaults.

Exact part-number definitions are expected to replace qualification/default
parameters as the part library grows.

## Shared Units

Public boundaries accept typed `UnitQuantity` values and supported engineering
text forms rather than requiring callers to pre-normalize to SI:

```rexx
v  = .DCVoltageSource~new('V1', '9000 mV')
r1 = .Resistor~new('R1', '1 kΩ')
c1 = .Capacitor~new('C1', '220 nF')
l1 = .Inductor~new('L1', '10 mH')
```

Dimension mismatches fail closed. Internally the numerical solver uses canonical
values supplied by Units.

## Physics optical boundary

Electrical lamp power can become Physics optical propagation and return as a
physical observation at a light sensor:

```text
Rexx-tronics lamp electrical state
        -> explicit power/intensity transfer
        -> Physics optics / prism / mirror / occlusion / photometry
        -> typed illuminance observation
        -> part-specific photoresistor response
        -> Rexx-tronics electrical state
```

No universal lamp or CdS law is invented.

## Physics acoustic boundary — dev10

Dev10 adds `RexxTronicsAcoustics.cls` and `LinearMicrophoneTransducer`.

Physics `AcousticSampleBuffer` pressure samples can now drive a real two-terminal
time-varying electrical component. The first transducer is deliberately an ideal,
flat linear qualification model with explicit sensitivity in V/Pa, optional DC
bias, output rails, and LINEAR/HOLD sample interpolation.

```rexx
sensitivity = .Units~q('0.010', .Units~volt / .Units~pascal)
mic = .LinearMicrophoneTransducer~new(
        'MIC1', sensitivity, '2.5 V', '0 V', '5 V')
mic~bindAcousticBuffer(physicsBuffer)

trace = .VirtualOscilloscope~new~acquireSignal(
        mic, startPs, durationPs, '96 kHz')
```

A real microphone part definition should eventually provide its actual
frequency response, sensitivity, self-noise, distortion and overload limits.
Those properties are intentionally not guessed by the generic class.

## The deliberately ridiculous qualification

The dev10 peer suite executes the following chain:

```text
1 kg finite-contact rigid block
        -> Physics contact event
        -> explicit structural vibration mode
        -> Physics retarded acoustic pressure
        + 136 dB SPL / 1 kHz pressure at microphone
        -> physical pressure sample buffer
        -> Rexx-tronics microphone transducer
        -> electrical voltage waveform
        -> Rexx-tronics virtual oscilloscope
```

The exact 136 dB value is defined **at the microphone** using the standard
20 µPa SPL reference, which is about 126.191468896 Pa RMS. It is a simulation
qualification input, not a recommendation for a real sound exposure.

The structural mode used for the qualification block is also explicit test data;
Rexx-tronics/Physics do not infer universal acoustic properties merely from the
word "steel".


## Reciprocal electromechanics — dev11

Physics World dev8 introduced the ideal reciprocal linear and rotary transducers retained by the dev10 peer. Rexx-tronics
now consumes that boundary without moving winding resistance, inductance, switching
or terminal topology into Physics.

The electrical image of the ideal converter is `PhysicsBackEmfSource`; it is placed
in series with ordinary Rexx-tronics winding components. `PhysicsElectromechanicalDriveBridge`
turns the solved converter current into Physics `ElectricalDriveObservation` evidence.
`QuasiStaticElectromechanicalCoupler` performs an explicit staggered loop:

```text
electrical solve including present back EMF
        -> solved converter current
        -> Physics force/torque
        -> mechanics step
        -> new velocity/angular velocity
        -> Physics reciprocal back EMF
        -> next electrical solve
```

Qualification includes both a linear voice-coil-style actuator and a rotary motor.
For the rotary fixture, a 3 V source, 1 ohm winding resistance and 0.5 N*m/A
converter begin at 3 A; after 200 ms the rotor is at 0.29625 rad/s, back EMF is
0.148125 V and current has fallen to 2.851875 A. Conversion power closure is
checked against Physics' reciprocal `tau*omega = e*i` evidence.

The dev11 coupler remains intentionally quasi-static on the electrical side. Dev12 adds a separate persistent transient coupler for R-L/C history rather than changing the meaning of the quasi-static API.

## BJT and display foundation — dev15

`RexxTronicsSemiconductors.cls` adds `BipolarJunctionTransistor`,
`NPNTransistor` and `PNPTransistor`.  The compact model is deliberately
piecewise-linear and inspectable: `CUTOFF`, `ACTIVE`, and `SATURATED` are
explicit operating regions.  Forward-active collector current is controlled by
the base-emitter branch through an MNA voltage-controlled current source;
saturation is an explicit finite `Vce(sat)` / resistance branch.  Parameters are
qualification defaults until replaced by exact part-number definitions.

`RexxTronicsDisplays.cls` adds an electrically solved seven-segment display.
Each segment is its own protected LED branch to a common terminal and therefore
contributes real current and power to the surrounding circuit.  `displayedDigit`
is derived from the seven solved segment states; it is not an independently
assigned UI value.

The source-backed Project 14 fixtures reproduce the manual's separate PNP and
NPN demonstration schematics, including their stacked positive and negative
rails.  Project 15 ties all seven display segment inputs to +9 V and uses the
NPN transistor as the low-side common switch, so pressing S1 produces a solved
`8`.  The manual identifies built-in display protection resistors but not their
value; the fixture's 1 kOhm segment resistance is therefore explicit
qualification data rather than a claim about the historical display.

## Qualification

Default electrical suite:

```sh
./run_tests.sh
```

Physics peer integration:

```sh
./run_physics_tests.sh
```

Focused Maths/Physics optics peer checks:

```sh
./run_peer_optics_tests.sh
```

The pinned Physics dev10.1 package remains unmodified and reconciles the 2-D free-surface and brittle-fracture development lines. Rexx-tronics runs its complete focused optical, acoustic, thermal, electromechanical, fracture/electrical and free-surface/electrical peer-integration suite against that exact tree. The peer package retains its own supplied validation evidence; Rexx-tronics does not relabel that entire peer suite as freshly rerun.

## Pinned qualification dependencies

- Units v0.1-dev4 — `b0916df3d8b68f1681f219e0e8770e490a6f7c00165cc5959b84d14354d4fa46`
- Maths v0.8 — `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`
- Physics World v0.1-dev10.1 — `936737a18d2c96a627e86d322b3dbf6bda06134a2410fc7eafb58c750cf6cc3c`
- ooRexx 5.3.0 r13196 Internal Test Version

### New in dev14

Dev14 consumes Physics World dev10.1's merged 2-D free-surface plus fracture authority. `PhysicsFreeSurfaceDepthProbe2D` samples the authoritative `RectangularTankSlosh2D` state; `LinearLiquidLevelTransducer` turns that physical depth into a real two-terminal electrical source only through an explicit calibration; `FreeSurfaceElectricalCoupler2D` advances Physics and the persistent electrical solver to the same simulation-time endpoint.

The qualification drives a rectangular tank diagonally, reads two opposite corner cells, and watches the resulting two electrical level-sensor channels on the ordinary Rexx-tronics virtual oscilloscope. No hydrostatic/free-surface approximation is duplicated in Rexx-tronics.

Dev14 also fixes a method-boundary precision leak in MNA stamping. High-precision Units quantities now remain high precision through matrix/RHS accumulation and resistor current calculation rather than falling back to ooRexx's default activation precision.

### New in dev13

Dev13 adopts Physics World v0.1-dev10's explicit brittle-fracture evidence and topology without copying its fracture laws. `PhysicsFractureConductor` lets a Physics `DeformableLink` be the physical authority behind an energized two-terminal electrical path. When Physics leaves the link intact, the configured conductor resistance is stamped normally; when Physics fractures that exact link, Rexx-tronics opens the internal path and the next electrical solution reflects the loss of continuity.

`FractureElectricalCoupler` demonstrates a contact-driven failure without an electrical damage heuristic: an ordinary Physics plane impact produces compression, Physics subsequently emits a `COMPRESSION` fracture event and splits the deformable body, then the powered 5 V / 1 kΩ electrical path falls from about 4.99995 mA to approximately 5 pA at the next common simulation-time endpoint.

The bridge retains fracture time, stress, criterion and energy evidence. It does not claim arcing, strain-dependent resistance, Joule-heating fracture, electromigration or fracture-generated acoustics.

### New in dev12

Dev12 makes transient electrical state persistent across externally partitioned simulation. `Circuit~newTransientStepper(clock)` allows one R/L/C timestep at a time without reinitializing capacitor or inductor history, and `TransientElectromechanicalCoupler` uses that facility to couple real winding inductance to Physics World reciprocal motor/voice-coil mechanics and back EMF.

Physics World is rebased to the exact user-supplied dev9 tree. Its new continuous driven-acoustic and lumped-thermal surfaces are consumed without copying their physics: the loudspeaker fixture generates pressure from actual resolved diaphragm motion, and `ElectricalDissipationThermalBridge` projects explicit positive electrical dissipation into a Physics `ThermalNode`.

Dev12 also adds a genuinely electrical regulator-stability experiment. `FeedbackLinearRegulator` has a finite VIN-to-VOUT pass path plus explicit three-pole internal control state; `COUT` is an ordinary Rexx-tronics `Capacitor`. The model never checks whether a capacitor exists and never declares all capacitor-less regulators unstable. In the qualification profile, a high loop gain oscillates after a load step when `COUT=0`, while 100 uF damps the same loop. A lower-gain no-Cout profile stays settled, demonstrating that the behavior comes from the configured loop dynamics rather than a hard-coded missing-cap rule.

```text
Vin -> finite regulator pass element -> OUT -> load
                                  |
                                  +-> optional real COUT -> GND

OUT -> feedback error -> pole 1 -> pole 2 -> pole 3 -> pass conductance
```

Exact regulator part definitions should supply target voltage, pass limits, loop gain/poles and any datasheet-required output-network constraints.
