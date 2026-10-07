# Source / prior-art provenance — ooRexx Maths v0.17

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

## v0.9 Physics consumer study

The current Library artifact `oorexx_physics_world_v0.1-dev26.zip` (SHA-256 `145a1621f6a31e4f06d20f0003087278ebb5661290f74bdf0b7093b2ffee1e2b`) was inspected as a **consumer specification**, not copied as a Maths implementation. It showed repeated generic patterns: bounded linear/bilinear interpolation, sampled mean/RMS/Fourier projection, quadratic ray-intersection roots, and use of RxMath scalar functions at Physics numerical boundaries.

v0.9 implements those reusable mathematical concepts under Maths ownership. Physics-owned physical formulas, Units authority and PDE/solver semantics are deliberately not imported. Standard numerical formulas (affine/bilinear interpolation, direct Fourier projection, stable quadratic q-formula, Taylor/range-reduced scalar functions) are independently implemented in Maths.

## v0.11 current Physics/guitar consumer study

The current Library consumers used to identify and qualify the second-order seam were Physics World dev43, Rexx-tronics dev25 and Guitar Tab Audio dev3. Physics dev43's six-string mechanics advances coupled string and body modes with a local symplectic-Euler loop. Maths does not copy its physical ownership; a validation adapter projects the current Physics-owned masses, damping, stiffness and bridge/nut coupling into generic `M`, `C` and `K` matrices and asks Maths to execute the same discrete scheme.

The accelerated implementation is Maths-owned provider code using NumPy arrays and SciPy `lu_factor`/`lu_solve` for factor reuse. The independent reference lane is ooRexx Maths and does not use SciPy. The direct consumer validation compares terminal displacement/velocity across all 32 projected DOFs and records numerical residuals rather than treating runtime speed as correctness evidence.



## v0.13 constants registry

The registry architecture and public catalogue are native ooRexx Maths code. PI continues to use the existing Maths high-precision implementation. TAU is derived as 2*PI; E through the existing `exp(1)` implementation; GOLDENRATIO and SQRT2 through existing high-precision square root operations. The Euler-Mascheroni seed was generated independently at 260 decimal digits for packaging and is deliberately exposed with a lower 250-working-digit capability bound so the runtime fails closed rather than claiming unavailable precision.

## v0.16 sampled state-space consumer seam
The v0.16 discrete state-space abstraction was driven by inspection of the
user's current Library `oorexx_physics_world_v0.1-dev46.8-acoustic-block-feedback.zip`
and `rexxtronics_v0.1-dev25.zip`.  No Physics or Rexx-tronics source is copied
into Maths.  Their domain semantics remain external; Maths only publishes the
generic discrete LTI recurrence, continuation state and provider policy.
