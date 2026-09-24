# Rexx-tronics public API notes — v0.1-dev15

## Quantity input policy

Public electrical inputs accept:

1. an ooRexx Units `UnitQuantity` of the required physical dimension;
2. a textual quantity recognized by the shared Units parser (for example `4.7 kΩ` or `250 mV`);
3. the historical naked numeric, interpreted in the canonical unit documented below.

| API | Quantity dimension | Legacy numeric meaning |
|---|---|---|
| `Resistor~new(id, resistance, tolerance, powerRating)` | resistance, ratio/percent, power | ohm, percent, watt |
| `VariableResistor~new(id, min, max, position, ...)` | resistance, resistance, ratio | ohm, ohm, 0..1 |
| `Potentiometer~new(id, totalResistance, position)` | resistance, ratio | ohm, 0..1 |
| `Switch~new(..., closedResistance, openResistance)` | resistance | ohm |
| `Capacitor~new(id, capacitance, initialVoltage)` | capacitance, voltage | farad, volt |
| `Inductor~new(id, inductance, initialCurrent)` | inductance, current | henry, ampere |
| `Diode~new(id, Vf, Ron, Roff [, Vbr, Rrev, hysteresis])` | voltage, resistance | volt, ohm |
| `ZenerDiode~new(id, breakdown, ...)` | voltage, resistance | volt, ohm |
| `LED~new(id, Vf, Ron, lightThreshold [, radiantEfficiency, wavelength])` | voltage, resistance, current, ratio, length | volt, ohm, ampere, 0..1, metre |
| `PhotoResistor~new(id, curve, initialIlluminance, ...)` | illuminance + response-curve resistance | typed illuminance strongly preferred |
| `PhotoResistor~applyIlluminance(value [, time [, cause]])` | illuminance, time | typed illuminance, simulation time |
| `DCVoltageSource~new(id, voltage)` | voltage | volt |
| `StepVoltageSource~new(id, initial, final, stepTime)` | voltage, voltage, time | volt, volt, picosecond/`SimInstant` for time |
| `DCCurrentSource~new(id, current)` | current | ampere |
| `DigitalOscillator~new(..., frequency, high, low)` | frequency, voltage, voltage | hertz, volt, volt |
| `VirtualOscilloscope~acquire*` | time, time, frequency | picosecond, picosecond, hertz |
| `SimulationClock~runFor/schedule*` | time | picosecond/`SimInstant` |
| `Circuit~simulateTransient(clock,duration,step)` | time, time | picosecond/`SimInstant` |

Wrong physical dimensions fail before solver use.

## Units boundary helpers

- `RexxTronicsUnits~canonical(value, expectedUnit [, label])` validates/converts and returns the canonical scalar expected by the solver.
- `RexxTronicsUnits~typed(value, expectedUnit [, label])` validates while preserving the `UnitQuantity` source/display-unit identity.
- `RexxTronicsUnits~fromMetadata(metadata [, expectedUnit [, label]])` reconstructs the authoritative Units metadata shape and optionally dimension-validates it.
- `RexxTronicsUnits~timePicoseconds(value [, numericUnit])` projects compatible time onto exact integer simulation picoseconds.

## Quantity-valued result accessors

- `ElectricalNet~voltageQuantity`
- `ElectricalNet~voltageAtQuantity(time)`
- `Pin~voltageQuantity`
- `DCSolution~voltageQuantity(net [, displayUnit])`
- `DCSolution~currentQuantity(component [, displayUnit])`
- `DCSolution~powerQuantity(component [, displayUnit])`
- `TransientResult~voltageAtQuantity(net,time [, displayUnit])`
- `TransientResult~currentAtQuantity(component,time [, displayUnit])`
- `Resistor~resistance`, `~tolerance`, `~powerRating`, `~current`, `~power`
- `Potentiometer~totalResistance`, `~currentAW`, `~currentWB`
- `Switch~current`
- `Capacitor~capacitance`, `~storedVoltage`, `~current`, `~power`
- `Inductor~inductance`, `~storedCurrent`, `~current`, `~power`, `~storedEnergy`
- `Diode~forwardVoltage`, `~voltageDrop`, `~current`, `~power`, `~state`
- `LED~lit`, `~opticalPower`, `~wavelength`
- `DCVoltageSource~voltage`
- `DCCurrentSource~current`
- `DigitalOscillator~frequency`, `~period`, `~highVoltageQuantity`, `~lowVoltageQuantity`
- `OscilloscopeTrace~measuredFrequencyQuantity`, `~minVoltageQuantity`, `~maxVoltageQuantity`, `~sampleInterval`
- `ScopeSample~time`, `~voltageQuantity`
- `SimInstant~quantity`

The original numeric result methods/attributes remain as compatibility/internal dense-solver surfaces in dev5.

## Inductor model

`Inductor` is ideal in dev5. At DC steady state it stamps a zero-volt MNA branch so it behaves as a short while retaining branch-current observability. During transient analysis it uses the backward-Euler companion relation:

```text
i[n] = i[n-1] + (dt/L) * v[n]
```

with explicit initial current.


## Semiconductor model

`Diode` is a two-terminal ANODE/CATHODE device with a piecewise-linear operating law. `ZenerDiode` configures reverse breakdown. `LED` inherits the electrical diode law and adds optical observations; `opticalPower` is `.nil` unless a radiant efficiency has been supplied, so the generic component does not invent a datasheet value.

The DC/transient solution `iterations` field reports the nonlinear matrix iterations needed for the accepted operating region.

## Reference-kit fixtures

`RexxTronicsKits.cls` contains source-backed project construction recipes. `Maxitronix500Project007` exposes `circuit`, `source`, `resistor`, `led`, `key`, `press`, `release`, and `solveDC`. These fixtures are ordinary component graphs and are intended as qualification inputs, not a parallel simulator.


## Environmental / Physics sensor boundary (dev7)

- `LightResistancePoint~new(illuminance,resistance)` stores one evidence point.
- `LightResistanceCurve~new(points [, belowPolicy [, abovePolicy]])` performs deterministic piecewise-linear interpolation; range policy is `ERROR` or explicit `CLAMP`.
- `LightResistanceCurve~resistanceFor(illuminance)` returns a resistance quantity.
- `IlluminanceObservation~new(illuminance [, time [, cause [, source]]])` carries typed physical input plus simulation-time/provenance evidence.
- `PhotoResistor~applyObservation(observation)` converts the physical observation to electrical resistance.
- `PhotoResistor~scheduleIlluminance(clock,when,value [,cause])` schedules the environmental change on authoritative simulation time.
- `PhotoResistor~illuminance`, `~lastStimulusTime`, and `~lastStimulusCause` expose the accepted physical state/evidence.

The initial response curve is deliberately not a universal CdS law. Exact part definitions should populate it from manufacturer evidence; future spectral sensor models can add richer Physics inputs without changing the electrical solver.


## Physical emitter boundary (dev9)

- `PowerIntensityPoint~new(power,intensity)` stores one evidence point using power and luminous-intensity quantities.
- `PowerIntensityCurve~new(points [, belowPolicy [, abovePolicy]])` provides deterministic piecewise-linear power -> candela projection; extrapolation is `ERROR` unless explicit `CLAMP` is configured.
- `PhotometricLamp~new(id,resistance,curve [,tolerance [,powerRating]])` is electrically a `Resistor` and exposes:
  - `power`
  - `luminousIntensity`
  - `luminousIntensityCandela`

The class is intentionally quasi-static.  It does not invent filament temperature, warm-up, spectrum or efficacy.

## Physics World adapter (dev9, optional)

`RexxTronicsPhysics.cls` requires Physics World dev4's `Coupling.cls`.

### `PhysicsBeamIlluminanceAdapter`

Constructor:

```text
PhysicsBeamIlluminanceAdapter(probe, intensitySource [, name])
```

`intensitySource` may be a typed candela quantity or an object implementing `luminousIntensity` (for example `PhotometricLamp`).

Methods:

- `currentIntensity`
- `sample([time [,cause]]) -> IlluminanceObservation`
- `sampleAndApply(photoResistor [,time [,cause]])`
- `scheduleSample(clock,when,photoResistor [,cause])`

Scheduled sampling evaluates the Physics world at event execution time on the authoritative simulation clock.

### `PhysicsIlluminanceEvidence`

Exposes:

- `reading` — the original Physics `OpticalBeamReading`;
- `sourceIntensity`;
- `baselineIlluminance`;
- `transmission`;
- `receivedIlluminance`;
- `distance`;
- `sensorWidth`;
- `sensorHeight`;
- `wavelengthNm`.

### Observation provenance

`IlluminanceObservation` now additionally accepts an optional `evidence` object.

`PhotoResistor` now retains:

- `lastStimulusSource`
- `lastStimulusEvidence`
- `lastObservation`

in addition to the existing simulation time and causal text.

## SimulationClock multi-event ordering (dev9)

`SimulationClock` guarantees deterministic execution by `(atPs, sequence)`.
Multiple queued events, including events at the same simulation timestamp, are
processed without sparse-array loss.  Equal-time events execute in scheduling
sequence order.  This matters for cross-domain coupling where geometry changes,
optical sampling and electrical consequences can share one simulated instant.


## Acoustic/electrical bridge (dev10)

### `LinearMicrophoneTransducer`

Constructor:

```rexx
unit = .Units~volt / .Units~pascal
mic = .LinearMicrophoneTransducer~new('MIC1', .Units~q('0.010', unit), '2.5 V', '0 V', '5 V')
mic~bindAcousticBuffer(physicsBuffer)
```

The component exposes `OUT` and `REF` pins, `pressureAt(time)`, `voltageAt(time)`, typed sensitivity/bias accessors, and transient voltage-source stamping.  `LINEAR` and `HOLD` pressure-sample interpolation are supported.  Requests outside the bound Physics sample window fail closed.

The model is intentionally ideal and flat.  Exact microphones should later provide part-number-derived sensitivity, frequency response, noise, distortion and overload behaviour rather than silently inheriting universal assumptions.


## Reciprocal Physics electromechanics (dev11)

### `PhysicsBackEmfSource`

Two-terminal `P`/`N` electrical component backed by a Physics dev10.1 reciprocal electromechanical transducer. It stamps the transducer's current back EMF as an MNA voltage source and exposes `backEmf`, `current`, and `conversionElectricalPower`.

Use ordinary Rexx-tronics `Resistor` and `Inductor` objects for winding copper loss and electrical storage; those do not belong inside Physics.

### `PhysicsElectromechanicalDriveBridge`

`applyFromSolution(solution,time[,cause])` reads the solved converter branch current and terminal voltage, creates a typed Physics `ElectricalDriveObservation`, invokes the transducer, and retains the returned linear/rotary actuation event.

### `QuasiStaticElectromechanicalCoupler`

Constructor:

```text
QuasiStaticElectromechanicalCoupler(circuit, mechanicsSolver [, simulationClock])
```

Methods:

- `addBridge(bridge)`
- `step(dt) -> ElectromechanicalCouplingStep`

Each step solves the current electrical state, applies all converter drives to Physics, advances mechanics, aligns the optional Rexx-tronics simulation clock, and re-solves against the new back EMF. The current implementation is explicitly quasi-static electrically and must not be used to claim preserved inductor history across partition steps.

### `ElectromechanicalCouplingStep`

Retains `startTime`, `endTime`, `preSolution`, `postSolution`, and the array of Physics `actuationEvents`.

## Persistent transient stepping (dev12)

`Circuit~newTransientStepper(clock)` returns a persistent `TransientSolver` whose dynamic component history is initialized once and retained across partitioned calls.

Methods:

- `begin(nominalStep)` — validate topology, establish the initial operating point and initialize capacitor/inductor state exactly once;
- `step(dt)` — advance one electrical interval on the shared `SimulationClock` while retaining dynamic history;
- `advance(duration, step)` — advance a persistent solver through multiple steps;
- `result` — accumulated `TransientResult` including the initial point and every stepped solution;
- `lastSolution`, `currentPs`, `initialized` — current persistent state.

The existing `Circuit~simulateTransient(clock,duration,step)` remains the one-shot facade and now uses the same persistent solver machinery internally.

## Persistent Physics electromechanical coupling (dev12)

### `TransientElectromechanicalCoupler`

Constructor:

```text
TransientElectromechanicalCoupler(circuit, mechanicsSolver, simulationClock, nominalStep)
```

Methods:

- `addBridge(PhysicsElectromechanicalDriveBridge)`
- `begin`
- `step([dt]) -> TransientElectromechanicalCouplingStep`
- `runFor(duration)`
- `result -> TransientResult`

This is the history-preserving R/L/C counterpart to the dev11 quasi-static coupler. Each partition performs one backward-Euler electrical step using the current Physics back EMF, applies the solved converter current to Physics, advances mechanics by the same interval, and leaves the new reciprocal back EMF live for the next electrical step.

It is deliberately a first-order staggered co-simulation scheme, not a fully implicit iterative electromechanical solve. Dynamic electrical history is authoritative and is never reset at coupling boundaries.

## Feedback regulator (dev12)

### `FeedbackLinearRegulator`

A three-terminal `VIN` / `VOUT` / `GND` electrical component with a finite
pass conductance and explicit internal three-pole control state.  It is a
transient control-loop model, not an ideal voltage clamp.

Constructor:

```text
FeedbackLinearRegulator(
    id,
    targetVoltage,
    basePassConductance,
    controlGain,
    pole1Time,
    pole2Time,
    pole3Time
    [, minimumPassConductance
    [, maximumPassConductance]])
```

`controlGain` has dimensions S/V.  Pole arguments are times.  Pass conductance
limits are ordinary conductance quantities.  The pass path is electrically
between `VIN` and `VOUT`; therefore input/output current and regulator
conduction loss are solved in the same MNA network as the load.

Observations:

- `targetVoltage`
- `passConductance`
- `passResistance`
- `outputVoltage`
- `inputCurrent`
- `power`
- `controlState1`, `controlState2`, `controlState3`

At each accepted transient step the regulator observes the solved output error,
advances its three first-order control states, and makes the resulting pass
conductance available to the next electrical timestep.  The individual poles
use backward-Euler coefficients; no internal state is updated during an
unaccepted nonlinear matrix trial.

The class does **not** inspect the circuit for an output capacitor.  `COUT` is
an ordinary `Capacitor`, so any stability or transient effect arises from the
configured loop state plus the actual electrical output network.  Exact
part-number definitions should provide loop parameters from evidence rather
than using the qualification profile as a generic regulator law.

## Explicit electrical -> thermal bridge (dev12)

### `TemperatureDependentResistor`

An ordinary resistor whose resistance is recalculated from a Physics dev10.1
`ThermalNode` using explicit reference resistance, reference temperature and
linear temperature coefficient.  Physics owns node temperature; Rexx-tronics
owns the electrical resistance stamped into the circuit.

### `ElectricalDissipationThermalBridge`

Projects **positive solved component dissipation** into a Physics
`ThermalPowerObservation`.  Negative electrical power is rejected rather than
silently reclassified as heat.

### `TransientElectroThermalCoupler`

A first-order staggered electrical/thermal co-simulation boundary using the
persistent electrical transient solver.  Electrical C/L history survives every
partition.  It is not a fully implicit electrothermal Newton solve.

## Physics fracture / electrical continuity

`RexxTronicsFracture.cls` is an optional Physics integration surface.

- `PhysicsFractureConductor~new(id, physicsLink [, intactResistance [, brokenResistance]])` binds one ordinary two-terminal electrical path to a Physics `DeformableLink`-like object. Physics owns the fracture decision; Rexx-tronics reads `link~broken`.
- `PhysicsFractureConductor~state` returns `INTACT` or `OPEN_FRACTURE`.
- `~fractureCriterion`, `~fractureTime`, `~fractureStress`, `~fractureEnergy`, and `~unresolvedFractureEnergy` expose retained Physics evidence after `~captureFractureEvidence(physicsSolver)`.
- `FractureElectricalCoupler~new(circuit, physicsSolver, clock)` advances a Physics deformable partition and then the persistent Rexx-tronics transient solver to the same simulation-time endpoint.
- `FractureElectricalCouplingStep` retains the Physics contact/fracture event arrays plus the electrical solution for that partition.

The bridge does **not** infer arcing, air-gap breakdown, strain-dependent resistivity, Joule-heating fracture, electromigration, magnetic force, or crack acoustics. Those require explicit additional models.
## 2-D free-surface electrical sensing (dev14, optional Physics peer)

- `FreeSurfaceDepthObservation~new(depth,time,xCell,zCell[,source[,cause[,evidence]]])` — typed depth/time plus Physics provenance.
- `PhysicsFreeSurfaceDepthProbe2D~new(sloshModel,xCell,zCell[,label])` — samples an authoritative Physics `RectangularTankSlosh2D` cell; `sample([cause])` retains the Physics snapshot as evidence.
- `LinearLiquidLevelTransducer~new(id,minDepth,maxDepth[,minVoltage[,maxVoltage[,rangePolicy]]])` — two-terminal OUT/REF electrical voltage source with explicit linear calibration. `rangePolicy` is `ERROR` or explicit `CLAMP`.
- `LinearLiquidLevelTransducer~applyObservation(observation)` — maps a physical depth observation into electrical output state.
- `FreeSurfaceDepthSensorBinding~new(probe,transducer)` — binds one Physics depth probe to one electrical transducer.
- `FreeSurfaceElectricalCoupler2D~new(slosh,circuit,clock,nominalStep)` — persistent staggered Physics/electrical coupling. Methods: `addBinding`, `begin`, `step([gx[,gz[,normalGravity[,dt]]]])`, `runFor(duration[,gx[,gz[,normalGravity]]])`, and `result`.

The generic linear level calibration is qualification infrastructure only. Production components should replace it with exact part-number transfer behaviour.



## Compact BJT model (dev15)

`RexxTronicsSemiconductors.cls` provides:

- `BipolarJunctionTransistor~new(id, polarity [, beta [, VbeOn [, RbeOn [, VceSat [, RceSat [, Roff [, hysteresis]]]]]]])`
- `NPNTransistor~new(id [, beta [, VbeOn [, RbeOn [, VceSat [, RceSat [, Roff]]]]]])`
- `PNPTransistor~new(id [, beta [, VbeOn [, RbeOn [, VceSat [, RceSat [, Roff]]]]]])`

Pins are `EMITTER`, `BASE`, and `COLLECTOR`.  Observations include `state`
(`CUTOFF`, `ACTIVE`, or `SATURATED`), `baseCurrent`, `collectorCurrent`,
`emitterCurrent`, `power`, `forwardVoltage`, and `saturationVoltage`.

`DCStampContext~stampVCCS(outputFrom,outputTo,controlPositive,controlNegative,gm)`
is the shared MNA primitive used by the forward-active model.  Positive `gm`
means current from `outputFrom` to `outputTo` equals
`gm * (VcontrolPositive - VcontrolNegative)`.

The model is intentionally compact and deterministic.  It does not claim an
Ebers-Moll/Gummel-Poon transistor, Early effect, junction capacitances,
frequency response, temperature coefficients, avalanche behaviour, or exact
part characteristics unless a later part definition explicitly supplies them.

## Seven-segment display (dev15)

`SevenSegmentDisplay~new(id [, commonType [, Vf [, segmentResistance [, lightThreshold [, offResistance [, hysteresis]]]]]])`
models seven independent protected LED branches sharing `COM`.  `commonType` is
`COMMON_CATHODE` or `COMMON_ANODE`; pins are `A` through `G` plus `COM`.

Useful observations:

- `segmentState(name)`
- `segmentCurrent(name)`
- `segmentLit(name)`
- `litSegments`
- `displayedDigit` (0-9 when the solved A-G pattern is an exact decimal digit)
- `power`

`displayedDigit` is derived from electrically solved segment currents.
