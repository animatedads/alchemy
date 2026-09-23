# Rexx-tronics public API notes — v0.1-dev5

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
