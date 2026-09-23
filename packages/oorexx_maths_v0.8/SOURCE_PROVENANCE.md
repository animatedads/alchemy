# Source / prior-art provenance — ooRexx Maths v0.8

The package was designed after checking existing ooRexx and external mathematical facilities rather than assuming a blank field.

## ooRexx prior art retained rather than duplicated blindly

- ooRexx RXMATH: compiled scalar/transcendental functions, historically documented around C `double` precision; useful provider/prior art, not a matrix/proof object system.
- ooRexx distribution `complex.cls` sample: demonstrates operator-overloaded complex/vector idioms; v0.4 preserves that stylistic precedent.
- Walter Pachl / Rexx high-precision mathematics work (`rxm.cls` / Math.cls line): relevant future scalar-provider prior art. The library does not reimplement a competing catalogue simply to own it.

## External provider sources

- NumPy / BLAS / LAPACK: accelerated numerical linear algebra.
- SymPy: symbolic algebra/exact manipulation.
- mpmath: arbitrary-precision arithmetic and interval context.
- python-flint / FLINT / Arb: exact integer/rational domains and arbitrary-precision real/complex ball arithmetic with rigorous error tracking.

Public references consulted during the v0.3/v0.4 design line include:
- https://pypi.org/project/python-flint/0.9.0/
- https://python-flint.readthedocs.io/
- https://flintlib.org/
- https://mpmath.org/doc/current/contexts.html
- https://docs.sympy.org/latest/guides/assumptions.html

Python-FLINT 0.9.0 (released 2026-07-03) documents support for CPython 3.10-3.14, FLINT 3.0-3.6, Linux manylinux binaries, and a fix for an `arb.neg()` bug. Maths therefore records provider versions and gates the Arb adapter at >=0.9.0.

## Bounded search conclusion

No claim is made that no other Rexx mathematical code exists. The design conclusion is narrower: the search did not identify an existing ooRexx package combining this library's operator-driven object model, explicit precision/domain transitions, replayable derivations, provider-neutral acceleration, claim-scoped proof outcomes, independent recomputation, exact rational matrix lane, implementation-lineage evidence, and optional cryptographic evidence/proof sealing, explicit proof plans, obligation/support route separation, and policy-driven automatic verification.

## v0.5 exact-number object model

v0.5's `.MathExactNumber` / `.MathRational` / `.MathInteger` / `.MathFraction` hierarchy and canonical-subtype factories are Maths-owned object semantics. They do not replace existing ooRexx scalar math libraries; they provide exact structural values and evidence-preserving operator behavior above integer arithmetic.

## v0.6 exact expansion and supplied regression

The v0.6 recurring-decimal implementation is Maths-owned code using standard exact rational mathematics: integer long division with remainder-cycle detection for rational -> base-10 expansion, and the standard geometric-series denominator `10^m * (10^n - 1)` for recurring-decimal -> rational conversion. No external CAS or floating-point library is used for this lane.

The 25-case rational round-trip regression is derived from the user-supplied `test.rex`, which demonstrated ordinary ooRexx finite-decimal materialisation for `(i/(3*i))*(3*i)`. The Maths regression expresses the corresponding calculation through `.MathFraction` objects and requires exact integer recovery with no tolerance.


## v0.7 quantization prior art and ownership

The quantization object model is Maths-owned and provider-neutral. The design was informed by bitsandbytes' public description of block-wise quantization, mixed storage/compute precision and serializable quantization state. Public references consulted:

- https://huggingface.co/docs/bitsandbytes/main/explanations/optimizers
- https://huggingface.co/docs/bitsandbytes/reference/functional
- https://github.com/bitsandbytes-foundation/bitsandbytes/blob/main/agents/architecture_guide.md

The NF4 codebook constants used by `.MathQuantizationCodebook~nf4` are the published bitsandbytes NF4 values:
`[-1, -0.6961928009986877, -0.5250730514526367, -0.39491748809814453, -0.28444138169288635, -0.18477343022823334, -0.09105003625154495, 0, 0.07958029955625534, 0.16093020141124725, 0.24611230194568634, 0.33791524171829224, 0.44070982933044434, 0.5626170039176941, 0.7229568362236023, 1]`.

Maths retains those decimal constants exactly for its reference codebook. This does not make the PURE provider a binary clone of bitsandbytes: v0.7 uses unpacked code indices and exact rational block scales, does not implement packed GPU layout or nested/compressed statistics, and makes no byte-for-byte compatibility claim.


## v0.8 3D mathematics ownership

The v0.8 3D family is Maths-owned provider-neutral mathematics. It uses standard vector, Hamilton-quaternion, homogeneous-transform and perspective/orthographic formulas rather than wrapping a graphics API. OpenGL/Vulkan/DirectX names identify explicit handedness/depth conventions only; no driver, GL library, GPU API or external 3D maths package is a dependency.

The high-precision angle path deliberately does not delegate to RXMATH because the established Maths precision constitution requires more than the documented C-double/16-digit ceiling for this lane. Degree reduction is performed before pi conversion where possible; radian reduction uses a bundled high-precision pi constant with a magnitude-aware working-precision gate.

The initial quaternion-rotation defect was traced to ooRexx caller-side expression evaluation under insufficient `NUMERIC DIGITS`, not to the Taylor recurrence itself. `ANGLE_REDUCTION.md` records the reproduction and the permanent precision-boundary rule.
