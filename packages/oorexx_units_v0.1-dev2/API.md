# API summary

`Units~q(value, unit [, displayUnit]) -> UnitQuantity`

`Units~convert(value, fromUnit, toUnit) -> value`

`Units~proof(value, fromUnit, toUnit) -> UnitProof`

`UnitQuantity~canonicalValue`, `~dimension`, `~sourceUnit`, `~displayUnit`, `~mathValue`, `~proof`

`UnitQuantity~in(unit) -> converted value`

`UnitQuantity~as(unit) -> quantity with changed display unit`

`UnitQuantity~convert(unit) -> UnitProof`

Arithmetic: `+`, `-` require compatible dimensions; `*`, `/` derive dimensions. Multiplication/division by plain scalars retains the quantity dimension.

Initial catalogue includes SI mechanics, temperature, electrical units, photometry, common metric prefixes and selected imperial length/mass units.

## dev2

`Units~version -> "0.1-dev2"`

`Units~parseUnit(expression) -> UnitDefinition`

Expressions support multiplication, division and integral powers, for example `kg*m/s^2` and `g/cm^3`.

`Units~parseQuantity(text) -> UnitQuantity`

`Units~fromMetadata(directory) -> UnitQuantity`

`UnitQuantity~metadata -> Directory` using schema `oorexx.units.quantity/0.1`.

Absolute temperatures subtract to temperature deltas. Absolute + absolute is rejected; absolute ± delta is supported; delta ± delta remains a delta.
