# Quantized mathematics — ooRexx Maths v0.8

Quantization is a declared lossy mathematical representation, not an invisible storage optimisation.

## Core objects

- `.MathDType`: storage/compute representation metadata.
- `.MathQuantizationCodebook`: named code values plus lineage.
- `.MathQuantizationScheme`: bit width, block size, storage/compute dtypes, codebook, rounding, nesting and provider hint.
- `.MathQuantizationState`: complete interpretation state, exact scales and exact represented-source error data.
- `.MathQuantizedVector` / `.MathQuantizedMatrix`: payload + state + represented-source snapshot + evidence/derivation.
- `.MathPrecisionPolicy` / `.MathMixedPrecisionPlan`: where loss is permitted and where high precision must remain.

## PURE reference semantics

The source values as presented to Maths are converted to exact rationals. Blockwise quantization then uses exact arithmetic.

### Symmetric INT8

For a non-zero block:

`scale = absmax / 127`

Each exact source value `x` maps to nearest-even integer `q` in `[-127,127]`, and reconstructs as:

`x_hat = q * scale`

The reference path retains exact `|x-x_hat|` and the exact half-step bound `scale/2`.

### NF4

The source block is divided by exact `absmax`; the normalized exact rational is mapped to the nearest value in the declared 16-entry NF4 codebook. Ties retain the lower code index for deterministic replay. Reconstruction is `code[q] * absmax`.

The reference provider certifies against the *declared codebook*. It does not claim that the decimal codebook is an exact transcendental construction of ideal normal quantiles, nor that its payload has a provider-specific packed binary layout.

## Claim semantics

`MathClaim~quantizationErrorBelow(tolerance)` asks a precise question: is the maximum absolute reconstruction error at or below `tolerance` over the retained represented source values under this quantization state?

The answer is replayed with exact rationals and can be `PROVED` / `EXACT_BOUND_CERTIFIED` or `DISPROVED` / `BOUND_EXCEEDED`.

It says nothing by itself about downstream model accuracy, financial-model suitability, measurement uncertainty, or information lost before the source values entered Maths.

## Mixed precision

Mixed precision is policy. Exact values are protected by default. Callers may protect semantic roles such as `BIAS`, configure a minimum tensor size, a higher-precision dtype, and an outlier threshold. Accelerated providers can consume this policy later without redefining it.

## Not implemented by PURE v0.8

Nested/double quantization is representable in the scheme object but execution fails closed. Packed nibble layout, GPU kernels, quantized optimizer state updates, and model-level quality claims belong to future accelerated/provider work.
