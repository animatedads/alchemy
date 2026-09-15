# ooRexx Maths v0.7

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
- `SYMPY`: optional symbolic equality proof route.
- `MPMATH-IV`: narrow direct-expression interval containment witness.
- `FLINT-ARB`: capability-gated python-flint/Arb rigorous ball provider, requiring python-flint >= 0.9.0.
- ooRexx Crypto: optional SHA-256 evidence/proof sealing.

v0.7 is rebased and qualified against Foreign Runtime v0.22.5 from `oorexxapis(20260901-121025).zip`.

## Test invocation

`run_tests.sh` prepends its own `rexx/` directory to `REXX_PATH`. Individual tests can also be run from the package root when dependency paths are present, for example:

```sh
rexx tests/test_flint_provider.rex
```

## Qualification

Assistant-host qualification: **269/269 executed assertions PASS** against ooRexx 5.3.0 r13196, Foreign Runtime v0.22.5, and Crypto v0.8.3 where applicable. FLINT-ARB remains an 8-assertion capability-gated lane to rerun on the user's python-flint-enabled host; if unchanged it raises the cross-environment total to 277/277.
