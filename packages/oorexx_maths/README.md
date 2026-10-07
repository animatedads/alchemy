# ooRexx Maths v0.17


## v0.17 — portfolio-review hardening

v0.17 is a correctness/qualification hardening release over v0.16. It adds no new mathematical family. It introduces an exact `compatibility-lock.json`, machine-readable qualification receipts, direct standards-enforcer gating, and repairs ooRexx language-safety findings (`&`/`|` short-circuit assumptions, numeric coercion idioms, reserved/discouraged result locals, and expected-condition diagnostics). Fresh qualification counts 599 enabled assertions PASS; FLINT-ARB is an explicit capability SKIP and Crypto is NOT_RUN in this pass rather than inherited as a new PASS. See `PORTFOLIO_REVIEW_HARDENING.md` and `QUALIFICATION.md`.

## v0.16 — discrete state-space continuation

v0.16 adds `.MathDiscreteStateSpaceSystem` for generic sampled LTI recurrences `x[k+1]=A*x[k]+B*u[k]`, `y[k]=C*x[k]+D*u[k]`, plus block continuation and snapshot/restore.  PURE retains exact/high-precision arithmetic; NumPy supplies an optional BINARY64 block provider.  AUTO provider selection is deliberately workload-aware because Foreign Runtime marshalling dominates tiny low-order filters.  See `DISCRETE_STATE_SPACE.md`.

## v0.15 — selected-channel second-order input/output dynamics

v0.15 adds `.MathSecondOrderInputOutputSystem` for `M*x''+C*x'+K*x=B*u` with selected linear outputs `y=Hx*x+Hv*x'`.  The native SciPy path performs input-force projection, propagation and selected-output projection in one provider route and returns only the requested channels plus the final full state.  See `SECOND_ORDER_INPUT_OUTPUT.md`.


A provider-neutral mathematical object, provenance and proof-planning layer for ooRexx.

The public surface is mathematical and operator-driven. Heavy computation may be delegated to native or Python providers, but providers do not own mathematical meaning, precision policy, exact-domain semantics, claim semantics or proof acceptance.

## Constitution

1. Decimal ooRexx work defaults to `NUMERIC DIGITS 50` semantics through `.MathContext~decimal(50)` plus guard digits.
2. Precision/domain transitions are explicit evidence. Binary64 is opt-in, never a silent acceleration route.
3. Exact values remain exact until the caller explicitly asks to leave the exact domain.
4. Formatting is presentation, not representation. Rendering `2/3` as a rounded decimal does not mutate the exact value.
5. Exact recurring decimal expansions are distinct from rounded decimal renderings. `2/3` may be displayed exactly as `0.(6)` without ever materialising a finite approximation.
6. Every non-trivial result can retain operation path, provider/version, algorithm, representation, guarantee scope, checks, warnings, derivation and implementation-lineage tags.
7. A proof proves a claim, under stated assumptions. `PROVED`, `DISPROVED`, and `INDETERMINATE` are distinct outcomes.
8. Proof obligations and supporting diagnostics are distinct. A small residual and an independently reproduced solution are different propositions.
9. Agreement is not accuracy. Duplicate approximate calculations do not establish N correct digits.
10. “Do it again differently” selects a materially different provider/algorithm where available.
11. Exact domains are preferred when the problem admits them; rigorous enclosure is distinct from exact algebra and from numerical reproduction.
12. A valid enclosure may still be weak. Containment and tightness are separate claims.
13. Domain packages (quant, risk, ML, valuation, network analysis, simulation, etc.) consume Maths rather than growing private mathematical implementations.


## v0.11 — native signal and coupled second-order dynamics

v0.11 keeps PURE/REFERENCE as mathematical authority while adding optional accelerated BINARY64 providers for workloads exposed by current Physics World and electric-guitar consumers. Native/vectorized lanes cover scalar transcendentals, vector/matrix operations, sampled/Fourier work, RFFT, convolution, damped oscillator banks, and now constant-coefficient coupled second-order systems

```text
M x'' + C x' + K x = f(t)
```

through `.MathSecondOrderLinearSystem`. Physics retains ownership of strings, bridge/body mechanics, forcing, energy accounting and causal evidence; Maths owns numerical propagation, provider choice and independent replay. Two integration schemes are explicit: `SYMPLECTIC_EULER` (matching current Physics dev43 stepping semantics) and `NEWMARK_AVERAGE_ACCELERATION` (beta=1/4, gamma=1/2). No method substitution is silent.

```rexx
ctx=.MathContext~binary64('SCIPY')
system=.Maths~secondOrderSystem(M,C,K,ctx)
final=system~integrateFinal(x0,v0,dt,steps,.nil,0,'SYMPLECTIC_EULER')
proof=final~prove(.MathClaim~independentlyReproduced('1E-7'))
```

The SciPy/NumPy provider factors constant matrices once and reuses the factorization at each step. `integrateFinal` deliberately returns only the final state when the caller does not need a complete trajectory, avoiding a large Python-to-ooRexx representation crossing. The accelerated result carries equilibrium/kinematic residuals and conditioning evidence; independent proof replays the same declared integration scheme through the REFERENCE provider with a different linear-solve implementation.

The RATIONAL lane executes the **discrete integrator equations exactly** where their arithmetic remains rational. This is not a claim that a finite-step discrete trajectory equals the exact continuous-time ODE solution.

A direct current Physics World dev43 six-string projection (32 DOF, 1,200 steps, same symplectic-Euler scheme) measured 10.624635 s in the local Physics loop versus 0.214728 s in Maths' SciPy final-state route in the sealed-artifact qualification rerun: **49.48x faster**. Final states agreed within declared binary64 migration tolerances (`max |dx| = 8.3e-11`, `max |dv| = 6.8e-8`), while the native represented-equation residual was about `6.94e-18`. See `SECOND_ORDER_DYNAMICS.md` and `VALIDATION_PHYSICS_DEV43_DYNAMICS.txt`.

## v0.9 — Physics-derived numerical foundations

v0.9 extends the reusable mathematical layer after inspecting the current Physics World dev26 consumer. It adds context-controlled high-precision scalar functions (`pi`, `sqrt`, `sin`, `cos`, `tan`, `exp`, `ln`, `log10`, `atan`, `atan2`), bounded 1-D/bilinear interpolation, sampled scalar/Fourier analysis, stable quadratic roots, and an explicit linear-system object over the existing matrix solver.

The ownership rule remains strict: Maths owns reusable mathematics; Physics owns physical meaning, conservation laws, force/energy equations, shallow-water fluxes, material semantics and Units. See `PHYSICS_NUMERICS.md`.

Representative usage:

```rexx
ctx=.MathContext~decimal(50)

value=.Maths~linearInterpolator(x,y,ctx)~evaluate(query)
component=.Maths~sampledSeries(ctx)~fourierComponent(20)
roots=.Maths~quadratic(a,b,c,ctx)~solve
solution=.Maths~linearSystem(A,b,ctx)~solve

say .Maths~sqrt(2,ctx)
say .Maths~atan2(y,x,ctx)~degreesValue
```

Exact-domain rules remain in force: `sqrt(9/16)` can remain exact `3/4`; `sqrt(2)`, π, and non-trivial transcendental functions fail closed under `RATIONAL` rather than returning an exact-looking approximation.


v0.14 qualification: **556 executed assertions PASS** on ooRexx r13196 with Foreign Runtime v0.22.6 and the NumPy/SciPy provider enabled; FLINT-ARB remains capability-gated because python-flint is absent.

## v0.14 — causal block continuation and sample delays

The guitar/monitor closed-loop consumer exposed a different seam after the v0.11 coupled-dynamics migration: the mechanics can be native, but a real feedback path still has a finite propagation delay and must preserve state across blocks. v0.14 adds generic mathematical state objects rather than guitar semantics:

```rexx
continuation=.Maths~secondOrderContinuation(system,x0,v0,0,'SYMPLECTIC_EULER')
delay=.Maths~sampleDelayLine(delaySamples,0,ctx)
trajectory=continuation~advance(dt,blockSteps,forceHistory)
delayedBlock=delay~process(outputBlock)
```

`MathSecondOrderContinuation` preserves displacement, velocity and simulation time across provider-selected integration blocks. `MathSampleDelayLine` is a bounded ring delay with snapshot/restore state. For a closed delayed loop, a domain consumer can choose a block no longer than its known feedback delay, compute its physical pickup/amplifier/speaker/air semantics outside Maths, and resume without violating causality. Maths does not interpret pressure, voltage, pickup response or acoustic coupling.

## 3D mathematics and transforms

v0.8 adds a provider-neutral 3D family: `.MathAngle`, `.MathVector3`, `.MathVector4`, `.MathMatrix3`, `.MathMatrix4`, `.MathQuaternion`, `.Math3DConvention`, `.MathTransform3D`, `.MathAffineTransform3D`, `.MathProjection`, `.MathPerspective`, `.MathOrthographic`, `.MathRay3D` and `.MathPlane3D`.

The core uses column-vector semantics and explicit handedness/depth conventions rather than hard-coding OpenGL storage or clip-space assumptions. OpenGL, Vulkan and DirectX convention objects are supplied; 4x4 matrices can be exported row-major or column-major without changing mathematical meaning.

```rexx
axis=.Maths~vector3(0,0,1,ctx)
q=.MathQuaternion~fromAxisAngle(axis,.Maths~angleDegrees(90,ctx),ctx)
rotated=q*.Maths~vector3(1,0,0,ctx)

model=.MathTransform3D~translation(1,2,3,ctx) * -
      .MathTransform3D~rotation(q,ctx) * -
      .MathTransform3D~scale(2,2,2,ctx)
```

The angle/trig implementation has an explicit precision-boundary regression: callers may be at `NUMERIC DIGITS 9` while the Maths context remains 50 digits, and half-angle division, negation, quaternion inversion and rotation must still retain the context precision. See `ANGLE_REDUCTION.md` and `MATH3D.md`.

## Exact numbers

```text
.MathExactNumber
    |
    +-- .MathRational
            |
            +-- .MathInteger
            +-- .MathFraction
```

Factories select the canonical subtype:

```rexx
third = .Maths~fraction(1,3)       /* MathFraction 1/3 */
one   = .Maths~fraction(3,3)       /* MathInteger 1   */
six   = .Maths~integer(6)

say six / 3                        /* 2   MathInteger */
say six / 4                        /* 3/2 MathFraction */
```

The defining exact regressions remain:

```rexx
third = .Maths~fraction(1,3)
answer = third + third + third
/* final arithmetic step retained as 3/3; canonical value is MathInteger 1 */

x = .Maths~fraction(2,3)
answer = x * 3 / 2
/* exactly MathInteger 1; no decimal expansion is materialised */
```

## Exact decimal expansions

v0.6 introduced `.MathDecimalExpansion`. It is an exact representation/view of a rational value, produced by exact integer long division with remainder-cycle detection.

```rexx
say .Maths~fraction(1,3)~format('EXPANSION')    /* 0.(3) */
say .Maths~fraction(2,3)~format('EXPANSION')    /* 0.(6) */
say .Maths~fraction(1,6)~format('EXPANSION')    /* 0.1(6) */
say .Maths~fraction(1,8)~format('EXPANSION')    /* 0.125 */
say .Maths~fraction(22,7)~format('EXPANSION')   /* 3.(142857) */
```

Recurring notation also parses exactly:

```rexx
.Maths~exact('0.(3)')       /* 1/3 */
.Maths~exact('0.1(6)')      /* 1/6 */
.Maths~exact('0.(9)')       /* MathInteger 1 */
```

`DECIMAL` remains explicitly approximate presentation; `EXPANSION` / `REPEATING` is exact base-10 expansion notation. Neither mutates the rational source.

`MathDecimalExpansion~prove` does not merely trust the source rational. For a recurring expansion it independently reconstructs the rational through the geometric-series conversion and requires exact equality with the long-division source before returning `EXACT`.

## Rational round-trip regression

The user-supplied test that evaluates `(i/(3*i))*(3*i)` exposed the ordinary finite-decimal round-trip problem. v0.7 retains it as a permanent exact regression for `i=1..25`:

```rexx
f = .Maths~fraction(i, i*3)
x = f * (i*3)
```

Every `f` is exactly canonical `1/3`; every `x` is exactly `.MathInteger(i)`. No tolerance is used.

`examples/rational_roundtrip.rex` shows the native decimal round trip beside the exact Maths path.

## Quantized and mixed-precision representations

v0.7 adds the deliberately lossy side of the same mathematical constitution. Quantization is represented as a value plus its full state rather than as anonymous low-bit bytes.

```rexx
A = .Maths~matrix(data, .MathContext~rational)
scheme = .MathQuantizationScheme~int8(64)
Q = A~quantize(scheme)

say Q~state~canonical
say Q~maxAbsError

proof = Q~prove(.MathClaim~quantizationErrorBelow('1/1000'))
```

The PURE v0.7 quantizer is a correctness/reference path. It first preserves the values presented to Maths as exact rationals, then performs block scaling and code selection with exact integer/rational arithmetic. It therefore certifies reconstruction error over the **retained represented source values**; it does not pretend to recover information already lost before those values entered Maths.

Two schemes are implemented by the reference path:

- `SYMMETRIC_INT8`: per-block exact `absmax/127` scale, signed payload `[-127,127]`, nearest-even code selection;
- `NF4`: the published 16-value bitsandbytes NF4 codebook, per-block absmax scaling, and unpacked code indices `0..15`. The reference path deliberately does not claim byte-for-byte compatibility with a specific packed GPU kernel.

`MathQuantizationState` retains scheme, block size, storage/compute dtypes, exact scales, source context, provider/version, exact observed maximum reconstruction error, and a declared error bound. Nested/double quantization is represented in the scheme model but the PURE provider currently **fails closed** when asked to execute it.

Mixed precision is policy rather than a hidden provider choice:

```rexx
plan = .Maths~mixedPrecision(.MathQuantizationScheme~nf4, 4096, 'FLOAT32')
plan~protect('BIAS')
plan~outliers(6)
```

Exact values are preserved by default; protected semantic roles and small tensors remain high precision, while sufficiently large approximate values may follow the default quantized path.

## Operator note

ooRexx dispatches overloaded arithmetic from the left operand. `fraction * 3` reaches Maths and remains exact. Bare `3 * fraction` is rejected by the built-in numeric left operand before the fraction object receives a message. Maths documents this language boundary rather than hiding it through lossy coercion.

## Matrices, vectors and proof planning

Ordinary `.MathVector` and `.MathMatrix` objects under `.MathContext~rational` retain exact-number objects. Decimal and binary64 contexts use their declared domains. Proof policies remain `STANDARD`, `STRONG`, `CERTIFIED`, and `DIAGNOSTIC`.

## Providers

- `PURE`: ooRexx decimal or exact rational arithmetic.
- `REFERENCE`: deliberately different verification algorithms; rational verification remains exact.
- `NUMPY`: optional resident NumPy acceleration via Foreign Runtime; binary64 must be explicitly selected.
- `SCIPY`: optional NumPy/SciPy provider for constant-coefficient second-order dynamics; binary64 only, with LU-factor reuse and residual/conditioning evidence.
- `RXMATH`: optional native C scalar provider for compatible binary64 scalar operations; never used to satisfy DECIMAL50 silently.
- `SYMPY`: optional symbolic equality proof route.
- `MPMATH-IV`: narrow direct-expression interval containment witness.
- `FLINT-ARB`: capability-gated python-flint/Arb rigorous ball provider, requiring python-flint >= 0.9.0.
- ooRexx Crypto: optional SHA-256 evidence/proof sealing.

v0.11 remains qualified against Foreign Runtime v0.22.5 from `oorexxapis(20260901-121025).zip`; the dynamics acceleration lane additionally uses NumPy 2.3.5 and SciPy 1.17.0 on the qualification host.

## Test invocation

`run_tests.sh` prepends its own `rexx/` directory to `REXX_PATH`. Individual tests can also be run from the package root when dependency paths are present, for example:

```sh
rexx tests/test_flint_provider.rex
```

## Qualification

Assistant-host v0.11 qualification: **514/514 executed assertions PASS** with RxMath, NumPy, SymPy/mpmath and accelerated Crypto sealing enabled. The native signal/physics acceleration lane contributes 49 assertions, and the coupled second-order dynamics lane contributes another 31, in addition to the 19 native scalar and 21 extended NumPy assertions. FLINT-ARB remains an 8-assertion capability-gated lane on the assistant host because python-flint is absent; the user can rerun that lane on the FLINT-enabled environment.


## v0.11 native acceleration

v0.11 keeps PURE/REFERENCE as the mathematical authority and adds optional accelerated BINARY64 execution lanes:

- native ooRexx RxMath C provider for scalar sqrt/trigonometric/exponential/logarithmic operations when the requested context is compatible with its ~16-digit binary64 capability;
- NumPy/Foreign Runtime vector add/subtract/scale/Hadamard/dot;
- native matrix multiplication, matrix-vector multiplication, solve and multiple-RHS inverse through NumPy's configured numerical stack;
- vectorized sampled-series mean/RMS and selected-frequency Fourier projection;
- native real-input FFT (`numpy.fft.rfft`);
- native full convolution, switching to zero-padded RFFT convolution for larger impulse responses;
- vectorized damped-oscillator-bank rendering for modal/harmonic workloads.

Every accelerated value retains provider/version/algorithm evidence and has an independent PURE/REFERENCE replay where the proof surface supports it. Fast paths are rejected when their precision domain cannot satisfy the requested context; RxMath, for example, cannot silently satisfy DECIMAL50.

A guitar-shaped benchmark on the qualification host (1024 samples, six damped modes, 64-tap impulse response) measured approximately 177x faster oscillator-bank rendering, 11x faster convolution and 953x faster 64-sample RFFT versus the PURE reference path. A 64x64 matrix-vector microcase was slightly slower through the foreign-provider bridge, demonstrating why provider choice must remain evidence- and workload-aware rather than treating native as automatically faster. See `VALIDATION_NATIVE_SPEED.txt`.



### Context-sized named constants

Use `.Maths~namedConstant(name, ctx)` for context-sized mathematical constants; `.Maths~constant(...)` retains its existing expression-constructor meaning. v0.13 promoted the earlier PI cache into a registry with exact structural constants, derived algebraic constants, transcendental constants, aliases, discovery (`constantNames`), and metadata (`constantInfo`). PI, TAU, E, Euler-Mascheroni, the golden ratio, sqrt(2), zero, one, and the imaginary unit are the initial catalogue.
