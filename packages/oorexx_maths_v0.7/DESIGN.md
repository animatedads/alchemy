# ooRexx Maths design constitution — v0.7

## Mathematical meaning belongs to Maths

Domain services define domain meaning. Maths owns reusable mathematical values, operations, numerical domains, claims, assumptions, proof paths and evidence. Providers compute; they do not redefine mathematics.

## Exact values are structural values

A rational is represented by exact integers, never by its decimal expansion. Reduction is exact and canonical. The exact hierarchy mirrors the subset relation:

```text
MathExactNumber
  MathRational
    MathInteger
    MathFraction
```

Factories normalize sign and gcd, then select `.MathInteger` when the reduced denominator is one and `.MathFraction` otherwise.

This means:

```text
1/3 + 1/3 + 1/3 -> 3/3 -> 1
(2/3) * 3 / 2   -> 1
```

without tolerance and without materializing `0.333...` or `0.666...`.

## Canonical value and derivation are different things

The value object should be canonical; the path should retain how it was obtained. Exact arithmetic evidence records both the unreduced result and the canonical result. Thus an integer result need not remain artificially represented as `3/3` merely to preserve explanation.

## Least-common-denominator addition/subtraction

Exact addition/subtraction use the gcd of denominators to form the least common denominator. This reduces intermediate integer growth and preserves intuitive paths such as `2/3 + 1/3 = 3/3` instead of an implementation-only `9/9`.

## Presentation is not representation

Formatting an exact value as decimal or mixed-number text cannot mutate its mathematical representation. A later exact operation therefore uses the original exact numerator/denominator regardless of previous presentation.

Leaving the exact domain for approximate computation must be an explicit operation/path transition. Approximate-domain tolerances are never used to excuse a wrong exact result.

## Operator semantics

Natural operators are overloaded where the mathematical meaning is unambiguous. ooRexx dispatches from the left operand, so exact objects should normally be the left participant in mixed expressions (`fraction * 3`). Maths does not make exact objects pretend to be Rexx numeric strings merely to make `3 * fraction` work; such a conversion would destroy the exact-domain contract.

## Result = value + derivation + evidence

A non-trivial `.MathValue` may retain its `.MathContext`, replayable `.MathDerivation`, and ordered `.MathEvidence` / `.MathPathStep` records. Path steps state provider/version, algorithm, representation, working precision, guarantee scope and implementation-lineage tags.

## Proof = claim + assumptions + plan + attempts + evidence

`.MathClaim`, `.MathAssumptions`, `.MathProofPolicy`, `.MathProofPlan`, `.MathProofRoute`, `.MathProofAttempt` and `.MathProof` preserve the distinction between what was claimed and what was merely useful supporting evidence.

`STANDARD`, `CERTIFIED`, `STRONG`, and `DIAGNOSTIC` keep their v0.4 semantics. Exact rational replay, symbolic proof, rigorous enclosure and independent numerical reproduction remain separate evidence lanes.

## No silent promotion of approximate answers to exact answers

If an exact calculation is routed through an approximate representation without explicit permission, that is a domain violation, not a tolerable rounding detail. In particular, a provider result such as `1.000000000000000000000001` is not accepted as the result of exact `(2/3)*3/2` merely because it is close to one.

## Exact decimal expansion

A recurring decimal is an exact representation of a rational number, not an approximate floating representation. v0.6 therefore models finite/recurring base-10 expansion as `.MathDecimalExpansion`, derived by exact integer long division and remainder-cycle detection. Rounded `DECIMAL` output and exact `EXPANSION` output are separate operations. A resource limit may abort expansion discovery, but no truncated sequence may be returned with an exact guarantee.

An exact expansion proof uses a second path: the generated notation is converted back to a canonical rational by the inverse finite-decimal/geometric-series construction and compared exactly with the source rational.


## Lossy representation is a mathematical state transition

Quantization is intentionally lossy and therefore cannot be modelled as a harmless storage detail. A quantized value retains the payload *and* the state required to interpret it: scheme, codebook, block structure, scales, storage dtype, compute dtype, provider/version, source-domain context and reconstruction-error evidence.

The bytes/codes alone are not the number.

The PURE reference quantizer converts the represented input values to exact rationals before choosing quantization codes. This makes its error analysis reproducible without depending on hardware floating-point rounding. The resulting certificate is deliberately scoped to those represented source values. If the source was already binary64, the certificate does not claim to recover the value before binary64 conversion.

## Blockwise quantization and outliers

Block size is part of mathematical representation state because it changes the scaling and therefore the reconstructed value. Per-block scaling can isolate an outlier from unrelated values. v0.7 regression tests demonstrate that `[1,100]` in a single symmetric-INT8 block incurs reconstruction error on `1`, while one-value blocks reconstruct both represented values exactly.

## NF4 is a codebook, not generic 4-bit floating point

The v0.7 NF4 reference scheme uses the published 16-value bitsandbytes codebook as explicit exact decimal constants and per-block absmax scaling. Maths records this lineage and does not reinterpret NF4 as IEEE-like sign/exponent/mantissa FP4. The reference payload is unpacked code indices; packed-provider binary layout is outside the current guarantee.

## Mixed precision is policy

A mixed-precision plan states where lossy representation is permitted and where higher precision must remain. Exact Maths values are protected by default. Semantic roles can be protected explicitly, and size/outlier thresholds are evidence-bearing policy values rather than hidden backend heuristics.

## Accelerated providers must be checked against meaning

A future bitsandbytes, PyTorch, CUDA, CPU-SIMD or other provider may accelerate quantization or quantized kernels, but it does not define the mathematical object. Provider output can be compared to the PURE reference quantizer and to claim-specific error bounds. Nested/double quantization is not silently approximated by the PURE provider; v0.7 fails closed until an implementation explicitly supports and evidences that state transition.
