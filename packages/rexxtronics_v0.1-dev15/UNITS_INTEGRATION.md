# Shared Units integration

## Authority

`oorexx_units_v0.1-dev4` owns dimensions, unit definitions, canonicalisation, conversion evidence, quantity metadata and unit parsing. Rexx-tronics owns circuit topology and electrical laws. Rexx-tronics must not grow a second unit catalogue or duplicate conversion constants.

At a public boundary:

```text
caller UnitQuantity / supported textual quantity / legacy scalar
    -> Units dimensional validation/conversion
    -> canonical SI scalar
    -> Rexx-tronics solver
    -> canonical electrical result
    -> UnitQuantity for public/result presentation
```

Naked numerics remain only as a compatibility path and use the documented canonical unit for that API position.

## Units dev4 changes relevant to Rexx-tronics

The dev2 shared package repairs the precision issue discovered by Rexx-tronics dev4. A high-precision scalar now crosses `Units~q()` unchanged under the library's 50-digit arithmetic boundary.

Dev2 also supplies:

- quantity metadata with schema `oorexx.units.quantity/0.1` and round-trip reconstruction;
- compound-unit construction/parsing;
- UTF-8 engineering aliases such as `Ω`, `kΩ`, `°C` and `°F`;
- absolute-temperature versus temperature-delta semantics;
- expanded engineering dimensions/units used by Physics and later Rexx-tronics models.

Rexx-tronics uses the metadata shape directly for cross-library/persistence interchange rather than defining a competing serialization schema.

## Text quantity convenience

Where the Units dev4 parser recognizes a unit token, Rexx-tronics typed boundaries accept text such as:

```text
4.7 kΩ
250 mV
220 nF
10 mH
5 V
2 ms
```

The parsed quantity is still dimension-checked against the receiving API. For example, `Resistor~new('R1', '5 V')` fails closed.

`UnitQuantity` remains the primary programmatic form and supports the full Units catalogue even when a textual alias is not provided by the parser.

## Currently integrated dimensions

- voltage (`V`, `mV`)
- current (`A`, `mA`)
- resistance (`ohm`, `kohm`, `Mohm`)
- capacitance (`F`, `uF`, `nF`, `pF`)
- inductance (`H`, `mH`)
- power (`W`)
- energy (`J`)
- frequency (`Hz`, `kHz`, `MHz` through UnitQuantity input)
- time (`s`, `ms`, `us`, `ns`, `ps` through UnitQuantity input)
- dimensionless ratio/percent for positions and tolerance

The shared catalogue is broader than the current electrical model; new component families should consume it rather than adding Rexx-tronics-local units.

## Simulation-time conversion

Simulation timestamps remain integer picoseconds. A `UnitQuantity` representing time is converted through Units to seconds and then exactly projected to picoseconds. Values that do not resolve to a whole picosecond fail rather than silently rounding.

Textual time quantities supported by the Units parser use the same path.

## Physics boundary

Rexx-tronics and Physics exchange typed `UnitQuantity` values plus simulation-time/causal provenance. Typical round trips are:

```text
electrical power -> optical/acoustic/mechanical Physics -> irradiance/pressure/force -> sensor -> electrical state
```

Neither side is permitted to reinterpret naked numbers by private convention at that boundary.


## dev4 engineering catalogue

Rexx-tronics uses the shared dev4 engineering-scale definitions rather than introducing aliases of its own. Compatibility qualification covers the new first-class micro/milli/kilo voltage/current/power/resistance/capacitance/inductance scales and GHz. The supplied dev4 parser currently does not expose every first-class unit token (notably `lx`), so environmental boundaries may pass typed `UnitQuantity` values directly; Rexx-tronics does not compensate with a private parser.
