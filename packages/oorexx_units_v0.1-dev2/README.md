# ooRexx Units v0.1-dev2

Independent dimensional quantity and unit-conversion library intended to be shared by ooRexx Physics World, Rexx-tronics and other numerical code.

A quantity carries three separate facts:

1. a canonical SI numeric/Maths value used for computation;
2. the unit in which the value entered the system (`sourceUnit`);
3. the unit in which it should currently be presented (`displayUnit`).

The canonical dimensional signature is a seven-component SI exponent vector (L, M, T, I, Θ, N, J). Derived units therefore prove compatibility algebraically: `kg * m / s^2` is the same dimension as N, and `V / ohm` is the same dimension as A.

`UnitDefinition` supports scale plus affine offset, so Celsius and Fahrenheit are representations of canonical kelvin rather than special-case strings.

The library deliberately follows the authoritative ooRexx Maths v0.8 vector scaling rule: scaling is `vector * scalar`; division by a scalar is implemented as multiplication by its reciprocal where a Maths payload is involved.

## Core classes

- `UnitDimension` — dimensional algebra.
- `UnitDefinition` — unit metadata and canonical transforms.
- `UnitQuantity` — value object retaining source and display units.
- `UnitProof` — replayable conversion derivation.
- `Units` — standard-unit catalogue / constructors.

## Examples

```rexx
r = .Units~q(4.7, .Units~kiloohm)
say r~in(.Units~ohm)             /* 4700 */

v = .Units~q(12, .Units~volt)
i = v / .Units~q(4, .Units~ohm)
say i~in(.Units~ampere)          /* 3 */

room = .Units~q(21, .Units~celsius, .Units~fahrenheit)
say room                         /* displayed in degF */
say room~sourceUnit~symbol       /* degC */
```

## Integration boundary

Physics should remove its private `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` and `SI` implementations and consume this library instead (a temporary compatibility facade can preserve those names while migrating callers).

Rexx-tronics should progressively replace member-name units such as `resistanceOhms`, `lastCurrentAmps`, `capacitanceFarads` with typed `UnitQuantity` values at public boundaries. Solvers may unwrap `canonicalValue` internally where dense numeric work benefits from it.

## dev2 additions

- absolute-temperature versus temperature-delta semantics (`degC`/`degF` versus `deltaC`/`deltaF`);
- arbitrary compound unit construction and parsing with `*`, `/`, and integral `^` exponents;
- quantity metadata with a stable schema marker and round-trip reconstruction;
- expanded engineering catalogue (volume, density, bar, eV, Wb, T, VA, var);
- common UTF-8 input aliases such as `Ω`, `kΩ`, `°C`, and `°F`;
- explicit 50-digit arithmetic boundaries so callers running at default `NUMERIC DIGITS` do not truncate conversion constants;
- stricter equality for equal-dimension but semantically different families.
