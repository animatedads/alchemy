# Architecture

## Authority

Units owns physical-dimension identity, conversion definitions, canonicalisation and conversion evidence. It does not own Physics mechanics, electrical circuit laws, or Maths algorithms.

Maths remains authoritative for numeric objects and vector/matrix/quaternion semantics. Units attaches dimensional meaning to mathematical values without changing Maths operator contracts.

## Representation

A `UnitQuantity` is a semantic mathematical value object with:

- `canonicalValue`: SI-space computational value;
- `dimension`: seven-base SI exponent signature;
- `sourceUnit`: immutable entry representation;
- `displayUnit`: presentation choice, independently mutable;
- `family`: optional semantic refinement for equal-dimension units where raw dimensional analysis is insufficient;
- `proof`: construction/conversion derivation.

The family refinement prevents invalid equal-dimension conversions such as candela to lumen while still allowing anonymous derived dimensions to be recognized algebraically.

## Maths interoperation

The payload is intentionally operator-oriented rather than coerced to a Rexx primitive. Multiplicative conversion therefore works with Maths values that implement arithmetic. In particular vector scaling uses `value * scale` and reciprocal scaling uses `value * (1 / scale)`, matching Maths v0.8 exactly.

Affine units are scalar-only because adding an offset to a vector has no generally valid physical meaning.

## Consumer policy

Public APIs should pass quantities, not encode units solely in method/member names. Numerically intensive inner loops may use canonical values provided the boundary converts back to a quantity before exposing results.

## Precision boundary

Unit scale/offset and quantity conversion methods establish `NUMERIC DIGITS 50` internally. This is deliberate: ooRexx arithmetic can otherwise inherit the caller/default precision before conversion objects have a chance to preserve exact engineering constants. Unit values supplied as character numerics therefore remain intact through the conversion boundary.

## Temperature semantics

Absolute temperature units and temperature-difference units share the same SI temperature dimension but have distinct kinds. Conversion and arithmetic fail closed across absolute/delta boundaries except for the physically meaningful operations: absolute - absolute -> delta, and absolute ± delta -> absolute.
