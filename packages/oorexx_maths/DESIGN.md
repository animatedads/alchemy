# ooRexx Maths design constitution — v0.17

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


## 3D semantic boundary (v0.8)

3D geometry belongs to Maths; graphics-API representation does not. Quaternion, transform and projection objects carry mathematical convention metadata. OpenGL/Vulkan/DirectX adapters may request layout/convention conversion but must not redefine the core objects.

Arithmetic precision is established before every 3D arithmetic boundary. In particular, a callee cannot repair precision already lost while evaluating one of its arguments, so callers inside the implementation do not pass expressions such as `r/2` into a helper until the enclosing method has selected working precision.

Exact rational algebra remains exact where mathematically closed. Irrational square roots, pi-based conversions and trigonometry require an approximate context unless a later exact symbolic provider explicitly represents the irrational quantity.

## Reusable numerical boundary (v0.9)

Current Physics World work exposed several generic mathematical mechanisms that belong below the domain layer. v0.9 therefore centralises scalar transcendental functions, interpolation, sampled/Fourier projection, quadratics and the explicit linear-system wrapper.

The boundary is semantic, not based on how much arithmetic a class contains. A Rusanov shallow-water flux, hydrostatic force law or acoustic radiation equation stays in Physics because its formula encodes a physical model. A bilinear interpolator or quadratic-root algorithm belongs in Maths because its meaning is mathematical and reusable by unrelated domains.

High-precision scalar routines obey `MathContext`; they do not silently route through RxMath's C-double ceiling. Rational exactness is retained when mathematically closed and otherwise fails closed.

## Coupled second-order dynamics boundary (v0.11)

The generic equation `M*x'' + C*x' + K*x = f(t)` is mathematical infrastructure and belongs in Maths. The interpretation of those matrices and forces remains with the consuming domain. Physics World therefore constructs mass/damping/stiffness/forcing from string, bridge, body, air and speaker models, while Maths propagates the declared system numerically.

Integration method is part of semantics and evidence. `SYMPLECTIC_EULER` and Newmark average acceleration are separate explicit choices; acceleration is never permission to substitute one for the other. The native SciPy lane reuses factorizations for constant matrices, and independent proof replays the same discrete scheme through REFERENCE with a different solve implementation.

Representation crossing is also part of performance semantics. A complete `(steps+1) x DOF` trajectory can cost more to marshal than to calculate, so `integrateFinal` is a first-class operation rather than a convenience wrapper around full-trajectory creation. This preserves the mathematical result requested by callers that need only terminal state without manufacturing unused representation.

Exact RATIONAL execution means exact evaluation of the selected **discrete equations**. It must not be described as an exact analytical solution of the continuous ODE.



## Constant registry boundary (v0.13)

Named mathematical constants are registry objects, not caller-owned recipes. The registry separates canonical identity and metadata from evaluated context-sized values. Exact structural values remain exact; derived constants retain authoritative mathematical derivations; evaluated values are cached only for their canonical name/domain/working precision. A finite precision source must advertise its capability and fail closed above it. Object-specific theorem results and distribution families are not automatically scalar constants merely because a numerical value is associated with them.
