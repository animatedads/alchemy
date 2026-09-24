# Physics integration — v0.1-dev15

Rexx-tronics uses ooRexx Physics World as a peer authority; it does not duplicate mechanics, optics or acoustics.

## Optical path

The retained optical boundary remains unchanged: Physics produces optical evidence/illuminance, and Rexx-tronics converts the physical observation through a part-specific photoresistor transfer curve into electrical state.

## Acoustic path

Dev10 consumes the public Physics `AcousticSampleBuffer` surface, retained in dev9.  `LinearMicrophoneTransducer` converts each pressure sample to electrical output using an explicit sensitivity in V/Pa plus optional bias and rails.  The model is a qualification model, not a universal microphone model.

Physics dev10.1 also supplies `GeneralContactMechanicsSolver`, `RigidContactHull`, `StructuralVibrationMode`, `StructuralAcousticCoupler`, and `MechanicalImpactAcousticRenderer`.  The qualification suite therefore exercises a finite-contact 1 kg box impact through structural vibration and retarded acoustic propagation before the result enters Rexx-tronics.

## Timing

Physics time and Rexx-tronics simulation time are aligned explicitly.  The virtual scope samples the resulting electrical signal in simulation time.  Host elapsed time is irrelevant.  Sample rates such as 48 kHz or 96 kHz that do not map to an integer number of picoseconds per sample are represented with the existing integer-picosecond acquisition quantisation; qualification records the resulting tiny frequency error rather than pretending it is absent.

## 136 dB qualification

The exact 136 dB SPL test defines pressure **at the microphone** using the standard 20 µPa reference, yielding about 126.191468896 Pa RMS.  This avoids inventing source directivity or distance.  The combined impact+yell test is simulation-only; 136 dB is not a recommended real-world exposure.


## Reciprocal electromechanical path

Rexx-tronics first adopted the peer's `ElectricalDriveObservation`, `LinearElectromechanicalTransducer` and `RotaryElectromechanicalTransducer` surfaces in dev11; the current dev10.1 peer retains those surfaces. Electrical and mechanical authorities remain separate.

```text
Rexx-tronics source / switch / winding R/L
        -> circuit solve
        -> PhysicsBackEmfSource branch current
        -> ElectricalDriveObservation
        -> Physics force/torque + equal/opposite reaction when configured
        -> Physics mechanics state
        -> reciprocal Physics back EMF
        -> PhysicsBackEmfSource voltage on next electrical solve
```

`PhysicsBackEmfSource` is an ideal controlled voltage source representing only the converter EMF. Copper loss remains an ordinary Rexx-tronics resistor; electrical energy storage remains an ordinary Rexx-tronics inductor. This keeps Physics' explicit power evidence meaningful instead of hiding terminal losses behind an efficiency scalar.

`QuasiStaticElectromechanicalCoupler` currently uses one DC electrical solve per partition step and then re-solves after the mechanics step. It therefore qualifies reciprocal feedback with resistive windings but deliberately does not claim coupled winding-inductance dynamics.

The bridge retains Physics actuation events, including terminal/conversion/mechanical power and power-closure evidence.

## Physics dev10.1 additional toys

The pinned dev10.1 peer retains the driven-acoustic and thermal modules introduced in dev9, which Rexx-tronics exercises directly:

- `DrivenAcoustics.cls`: retained `RigidRadiatingPatch` motion and `ContinuousMechanicalAcousticRenderer` turn actual resolved mechanics into retarded pressure samples. The Rexx-tronics speaker fixture drives this from real winding current through the reciprocal electromechanical path; there is no current-to-pressure shortcut.
- `Thermal.cls`: lumped `ThermalNode`, typed `ThermalPowerObservation`, thermal transfer and explicit integration. `RexxTronicsThermal.cls` only submits explicit positive electrical dissipation and reads temperature back; it does not silently reinterpret unassigned electrical power as heat.

The peer also retains the dev7 free-surface/slosh solver. Rexx-tronics does not duplicate it. Fluid level, force, pose or other future sensor observations should cross typed Units/evidence boundaries in the same way as optical, acoustic and thermal observations.

## R-L electromechanical co-simulation (dev12)

Dev12 adds the persistent transient counterpart to the dev11 quasi-static bridge. Ordinary Rexx-tronics `Resistor` and `Inductor` objects model winding copper loss and stored magnetic energy; `PhysicsBackEmfSource` remains the electrical image of the reciprocal Physics converter.

`TransientElectromechanicalCoupler` initializes the electrical transient solver once, then interleaves electrical and mechanical partitions on the same simulation timeline. Inductor current is therefore continuous across every Physics step instead of being silently reset by repeated DC solves.

The qualification motor uses a 3 V step, 1 ohm winding resistance, 0.1 H winding inductance, 0.5 N.m/A reciprocal torque constant and a 1 kg.m2 test inertia. The first 10 ms current is about 0.272727 A rather than jumping to the 3 A DC value; after 200 ms the winding retains about 2.516 A while rotor motion develops about 0.0855 V back EMF. The exact numbers are numerical-fixture evidence, not a claim about a particular physical motor.

## Fracture -> electrical continuity (dev13)

The fracture line adopted by Rexx-tronics in dev13 added explicit `BrittleFractureLaw`, retained `FractureEvent` evidence and `FractureTopology` / `FractureFragment` connected-component views; the current Physics World v0.1-dev10.1 peer retains that authority. Rexx-tronics consumes it through `PhysicsFractureConductor`.

An intact physical link stamps its configured electrical resistance. Once Physics marks that exact `DeformableLink` broken, the electrical component changes to its explicit open resistance and ceases to expose an internal graph path. `captureFractureEvidence()` retains the matching Physics event rather than manufacturing a second electrical fracture event.

The contact qualification is deliberately causal rather than heuristic: the first Physics partition creates an ordinary plane-contact impulse; the second partition sees the resulting compression and breaks the brittle link under its configured compressive criterion; only then does the powered Rexx-tronics path open.

Current boundary: no crack-generated acoustics, electrical arc across the opening, changing resistance under elastic/plastic strain, thermally driven fracture, or remeshed shard-contact electrical conduction. Physics dev10.1 itself likewise documents that its fracture model is axial-link/cohesive topology rather than arbitrary crack-surface/remeshing fracture.
## Physics dev10.1 2-D free surface -> electrical level sensing (dev14)

`RexxTronicsFluids.cls` consumes the public `RectangularTankSlosh2D` state without reimplementing shallow-water physics. `PhysicsFreeSurfaceDepthProbe2D` samples one authoritative cell depth and retains the Physics snapshot as evidence. `LinearLiquidLevelTransducer` is a generic calibrated depth-to-voltage electrical source; its calibration is explicit qualification/part-definition data, not a universal sensor law.

`FreeSurfaceElectricalCoupler2D` is an explicit staggered partition: Physics advances the free surface to `t+dt`, probes sample that endpoint, electrical transducers accept the observations, and the persistent Rexx-tronics transient solver advances to the same `t+dt`. This preserves electrical C/L history and shared simulation time while keeping solver authority separate.

The dev14 fixture drives a 0.6 m x 0.4 m tank for 90 ms under simultaneous X/Z effective gravity and sends opposite-corner depth observations to two 0–5 V qualification channels. The resulting electrical traces are acquired by the existing virtual oscilloscope.

Current boundary: no generic capacitive/ultrasonic/pressure/float-sensor physics is invented, no wet-electrode conductivity model is implied, and Rexx-tronics does not derive local hydrostatic pressure from the slosh field. Those require explicit sensor/Physics models.

