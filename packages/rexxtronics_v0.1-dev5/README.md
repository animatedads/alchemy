# Rexx-tronics v0.1-dev5

Executable ooRexx electronics-model kernel.

v0.1-dev5 rebases Rexx-tronics on **ooRexx Units v0.1-dev2**, confirms the shared library's precision repair, adds stable Units-metadata interchange and textual engineering-quantity convenience, and extends the transient electrical model with an ideal inductor.

## Shared Units contract

Rexx-tronics does not require callers to pre-normalize values to SI. Public component/instrument boundaries accept typed `UnitQuantity` values and validate their physical dimension before numerical values reach the solver.

With Units dev2, supported parser forms may also be supplied directly:

```rexx
v  = .DCVoltageSource~new('V1', '9000 mV')
r1 = .Resistor~new('R1', '1 kΩ')
c1 = .Capacitor~new('C1', '220 nF')
l1 = .Inductor~new('L1', '10 mH')
```

The deterministic solver still uses canonical SI-space scalars internally. Results are available as quantities:

```rexx
solution = circuit~solveDC
say solution~voltageQuantity('MID')~in(.Units~millivolt)
say solution~currentQuantity('R1')~in(.Units~milliampere)
```

Dimension mismatches fail closed. A textual `5 V` cannot silently become a resistance.

Legacy naked numeric arguments remain accepted for compatibility and retain their documented canonical interpretation.

## Units dev2 precision and metadata

The precision loss observed against Units dev1 is repaired in the supplied dev2 dependency. A 50-digit input quantity now retains its scalar across `Units~q()` unchanged.

Units dev2 also provides stable metadata:

```rexx
q = .RexxTronicsUnits~typed('4.7 kΩ', .Units~ohm)
m = q~metadata
restored = .RexxTronicsUnits~fromMetadata(m, .Units~ohm)
```

The metadata schema is `oorexx.units.quantity/0.1`. Rexx-tronics uses that shared shape for persistence and future Physics coupling instead of inventing another quantity serialization.

## Time remains simulation time

Circuit physics uses **simulation time**, represented internally as integer picoseconds. Wall-clock execution speed never changes electrical behaviour.

```rexx
clock~runFor(.Units~q(20, .Units~millisecond))
clock~runFor('2 ms')
run = circuit~simulateTransient(clock,
        .Units~q(6, .Units~millisecond),
        .Units~q(10, .Units~microsecond))
```

A 500 Hz oscillator remains 500 Hz whether a simulated second takes minutes or milliseconds of host execution time. Instrument acquisition is independently expressed in simulation time and frequency.

## Electrical model

- `Circuit`, `ElectricalNet`, `Pin`
- explicit `GND`
- topology validation and electrical path tracing
- `Resistor`
- `VariableResistor`
- three-terminal `Potentiometer`
- `Switch`
- `Capacitor`
- `Inductor`
- `DCVoltageSource`
- `StepVoltageSource`
- `DCCurrentSource`
- linear modified nodal analysis (MNA)
- fixed-step transient analysis
- backward-Euler capacitor and inductor companion models
- solved node voltage, component current and power
- inductor stored-energy observation
- scheduled switch events on the authoritative `SimulationClock`
- virtual oscilloscope acquisition independent of wall time

## Example: RL step response

```rexx
clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.StepVoltageSource~new('VSTEP', '0 V', '5 V', '1 ms'))
r = c~add(.Resistor~new('R1', '1 kΩ'))
l = c~add(.Inductor~new('L1', '1 H'))

c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('RL',  .array~of(r~pin('B'), l~pin('A')))
c~connectGround(l~pin('B'))
c~connectGround(v~negative)

run = c~simulateTransient(clock, '6 ms', '0.01 ms')
say run~currentAtQuantity(l, '2 ms', .Units~milliampere)
```

With `R=1 kΩ` and `L=1 H`, the electrical time constant is 1 ms. The dev5 regression observes about 3.169746 mA one millisecond after the step and about 4.965805 mA after five milliseconds using the fixed 10 µs backward-Euler step.

## Physics boundary

The shared Units package is also the quantity authority for the separate ooRexx Physics work. Rexx-tronics stays authoritative for electrical state; Physics stays authoritative for optics, mechanics, acoustics and environmental propagation.

```text
Rexx-tronics electrical power/current
        |
        | UnitQuantity + simulation time + cause
        v
Physics environment / material propagation
        |
        | UnitQuantity observation + simulation time + cause
        v
Rexx-tronics sensor transfer characteristic
        |
        v
new electrical state
```

This permits, for example, electrical lamp power to drive optical propagation through a prism/mirror in Physics and return as irradiance at a light sensor without either library inventing private unit conventions.

## Dependency pin

The package contains an **unaltered qualification snapshot** of `oorexx_units_v0.1-dev2` under `deps/`. It is not a Rexx-tronics fork. Set `REXXTRONICS_UNITS_ROOT` to test against another compatible shared Units tree.

## Qualification

Run:

```sh
./run_tests.sh
```

The suite covers simulation-time authority, deliberate instrument aliasing, topology/path tracing, DC MNA, adjustable controls, switching, RC transient behaviour, shared Units integration, Units dev2 precision/metadata/text parsing, dimensional fail-closed behaviour, and RL/inductor transient behaviour.
