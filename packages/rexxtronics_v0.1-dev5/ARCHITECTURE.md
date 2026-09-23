# Rexx-tronics architecture — v0.1-dev5

## Authority boundaries

1. **Simulation time is authoritative for circuit behaviour.** Wall-clock duration is performance metadata only.
2. **Circuit topology is explicit.** Components own pins; nets connect pins; no behavioural layer may bypass the net model to manufacture a result.
3. **Electrical solvers are authoritative for voltage/current/power.** Instruments observe solver/event state; they do not create electrical truth.
4. **Instrument acquisition is independent.** A virtual instrument may undersample, alias, quantize or otherwise fail to observe a real simulated event without altering that event.
5. **ooRexx Units v0.1-dev2 is authoritative for physical dimensions, conversions and quantity metadata.** Rexx-tronics normalizes typed values at solver boundaries and does not own a private unit catalogue.
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
                    |
              integration models
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
