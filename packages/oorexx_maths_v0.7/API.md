# ooRexx Maths v0.7 API summary

## Core factories (`.Maths`)

- `~integer(value, context=.nil)` -> canonical `.MathInteger`
- `~fraction(numerator, denominator, context=.nil)` -> `.MathFraction` or `.MathInteger` after exact reduction
- `~rational(numerator, denominator=1, context=.nil)` -> canonical exact rational subtype
- `~exact(value, context=.nil)` -> exact integer, fraction, finite/scientific decimal, or recurring-decimal parser
- `~decimalExpansion(value, maxDigits=10000, context=.nil)` -> `.MathDecimalExpansion`
- `~rationalFromDecimal(text, context=.nil)`
- `~matrix`, `~vector`, `~complex`, `~identity`, `~variable`, `~constant`, `~assumptions`
- `~rationalMatrix`, `~rationalVector`
- provider registry/query methods
- `~dtype(name)`, `~quantization(name, blockSize=64, computeType='FLOAT32', nested=.false)`, `~quantize(value, scheme=.nil)`, `~mixedPrecision(...)`
- `~planProof(value, claim=.nil, assumptions=.nil, policy=.nil)`
- `~prove(value, claim=.nil, assumptions=.nil, policy=.nil)`

## Exact numbers

`.MathExactNumber` is the exact-value base.

`.MathRational` supplies `numerator`, `denominator`, exact `+ - * / **`, exact `= \\= < > <= >=`, `abs`, `compareTo`, proof support, `toDecimal`, `decimalExpansion`, and formatting.

`.MathInteger` is the canonical denominator-one subtype. `.MathFraction` is the canonical proper-rational subtype.

Exact arithmetic evidence records the unreduced operation result and canonical result. `1/3 + 1/3 + 1/3` therefore retains `unreduced=3/3`, `canonical=1`, while returning `.MathInteger(1)`.

## `.MathDecimalExpansion`

Exact base-10 representation of a rational value.

Methods:

- `string` -> exact finite/recurring notation, e.g. `0.1(6)`
- `integerPart`
- `nonRepeatingDigits`
- `repeatingDigits`
- `periodLength`
- `isTerminating`
- `isRecurring`
- `isExact`
- `source` / `toRational`
- `canonical`
- `evidence`
- `prove` -> for `IS_EXACT`, replay the expansion through an independent exact inverse conversion and require exact rational equality

`MathRational~format('EXPANSION')` and `~format('REPEATING')` render this notation. `~format('DECIMAL', digits)` remains an explicitly rounded presentation boundary.

`.Maths~exact()` accepts recurring notation such as `0.(3)`, `0.1(6)`, and `3.(142857)` and converts it algebraically to a canonical exact rational. `0.(9)` canonicalizes to `.MathInteger(1)`.

Expansion generation is exact integer long division. `maxDigits` is a resource bound: if a complete finite expansion or recurring cycle is not discovered within it, the operation fails rather than returning a truncated value falsely labelled exact.

## Context

- `.MathContext~decimal(digits=50, provider='PURE')`
- `.MathContext~binary64(provider='NUMPY')`
- `.MathContext~rational(provider='PURE')`
- `context~verificationContext`

## Evidence / derivation

`.MathPathStep`, `.MathEvidence`, `.MathDerivation`, and `.MathSeal` retain operation/provider/algorithm/domain/precision/representation/guarantee/lineage/check data.

## Claims / proof planner

Policies: `STANDARD`, `STRONG`, `CERTIFIED`, `DIAGNOSTIC`.

`.MathProofPlan`, `.MathProofRoute`, `.MathProofAttempt`, and `.MathProof` retain planned/executed proof paths. Claims include independent reproduction, equality, equation satisfaction, digits of accuracy, exactness, enclosure, and containment.

## Quantization / mixed precision

`.MathDType` models storage/compute representations such as `INT8`, `UINT8`, `FLOAT16`, `BFLOAT16`, `FLOAT32`, `FLOAT64`, and `RATIONAL`.

`.MathQuantizationCodebook` retains named code values and lineage. `~nf4` returns the 16-value bitsandbytes NF4 reference codebook as exact decimal rationals.

`.MathQuantizationScheme`:

- `~int8(blockSize=64, computeType='FLOAT32')`
- `~nf4(blockSize=64, computeType='BFLOAT16', nested=.false)`
- `name`, `bits`, `blockSize`, `storageType`, `computeType`, `codebook`, `nested`, `rounding`, `providerHint`, `canonical`

`.MathMatrix~quantize(scheme)` and `.MathVector~quantize(scheme)` return `.MathQuantizedMatrix` / `.MathQuantizedVector`. These retain payload, `.MathQuantizationState`, exact represented-source snapshots, evidence and derivation. `~dequantize(context=.nil)` reconstructs through an explicit path. Arithmetic operators on quantized values currently dequantize explicitly before using the ordinary Maths operation.

`.MathClaim~quantizationErrorBelow(tolerance)` is proved or disproved by exact rational replay over the retained represented source values. A successful proof strength is `EXACT_BOUND_CERTIFIED`; its scope is the declared quantization state, not unknown pre-Maths values or model-level accuracy.

`.MathPrecisionPolicy` and `.MathMixedPrecisionPlan` provide size thresholds, protected semantic roles, exact-value preservation, high-precision island dtype, and optional outlier thresholds.

## Vector / matrix

`.MathVector`: `+ - *`, index access, dot via `*`, evidence/derivation/proof.

`.MathMatrix`: `+ - *`, transpose, inverse, solve, row/column/index access, identity factory, evidence/derivation/proof.

Under `RATIONAL`, vectors/matrices retain `.MathInteger` / `.MathFraction` values exactly.

## Symbolic / interval / ball

`.MathExpression` subclasses use overloaded arithmetic. `~interval(bounds)` uses MPMATH-IV; `~ball(bounds)` uses FLINT-ARB when registered.

## Crypto

`MathCryptoEvidence.cls` provides SHA-256 sealing and verification for canonical evidence and full proof records.
