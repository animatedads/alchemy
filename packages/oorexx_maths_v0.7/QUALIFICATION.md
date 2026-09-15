# Qualification record — ooRexx Maths v0.7

## Provenance baseline

User-supplied roll-up: `oorexxapis(20260901-121025).zip`

- roll-up SHA-256: `b3166841ae88ac582e57d278ba862fab79b1ffb6da578e6e42d7ee6c3d084640`
- embedded Maths v0.5 baseline SHA-256: `cc72fcc7a068df2cb636ec116b75f5865d6b025219c65a42e344cbc0b4596423`
- Foreign Runtime v0.22.5 SHA-256: `c098aaabcbed14fdb80ca2a9aafece263fa092df5567014a485ce79e784711c2`
- Crypto v0.8.3 SHA-256: `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- Runtime Reference v0.4 SHA-256: `c42a0c51cc5f5e26056d22db97d53eae2633141a7cebe3304b5f19b1847f957a`

## Runtime

- user-supplied ooRexx 5.3.0 r13196 Internal Test Version, extracted and run in isolation;
- ooRexx Foreign Runtime v0.22.5 for NumPy/SymPy/mpmath provider tests;
- ooRexx Crypto v0.8.3 for evidence and full-proof SHA-256 sealing.

Observed Python stack: Python 3.13.5, NumPy 2.3.5, SymPy 1.14.0, mpmath 1.3.0; NumPy reports scipy-openblas for BLAS/LAPACK.

## Result on assistant qualification host

**269/269 executed assertions PASS.**

Breakdown:

- core operators / decimal matrix evidence and replay: 18;
- explicit claims / assumptions: 10;
- exact rational scalar arithmetic/proof: 15;
- exact-number hierarchy/canonicalization/formatting: 24;
- exact finite/recurring base-10 expansion, inverse exact replay proof, recurring-literal parsing, and resource-limit fail-closed behavior: 25;
- user-derived rational round-trip regression (`i=1..25`): 50;
- exact-reference INT8/NF4 quantization, state, error proof, blockwise/outlier and operator semantics: 31;
- mixed-precision policy/plan semantics: 9;
- exact rational vector/matrix/solve/replay: 15;
- proof planner core/policies/exact represented residual: 18;
- NumPy resident acceleration and adversarial independent disagreement: 14;
- NumPy planner / residual-vs-reproduction distinction: 8;
- SymPy + mpmath proof providers: 17;
- provider-aware proof planner: 9;
- Crypto evidence + full-proof sealing: 6.

The optional FLINT-ARB test is **SKIP** on this host because python-flint >= 0.9.0 is absent. That unchanged provider/planner test contains 8 assertions. The user's FLINT-enabled environment previously qualified v0.4 8/8; v0.7 should rerun these 8 assertions before claiming **277/277** across environments.

## Foreign Runtime v0.22.5 prerequisite checks

- NumPy reverse import: 3/3 PASS;
- NumPy zero-copy: 4/4 PASS;
- Python DLPack tensor: 15/15 PASS.

## v0.7 exact decimal-expansion regressions

- `1/3 -> 0.(3)`;
- `2/3 -> 0.(6)`;
- `1/6 -> 0.1(6)`;
- `1/8 -> 0.125`;
- `22/7 -> 3.(142857)`;
- recurring literals parse algebraically back to exact canonical rationals;
- `0.(9)` canonicalizes exactly to `.MathInteger(1)`;
- rounded `DECIMAL` rendering and exact `EXPANSION` rendering remain distinct;
- rendering cannot contaminate later exact arithmetic;
- expansion search is resource-bounded and fails rather than emitting a truncated sequence with an exact label.

## User-derived rational round-trip regression

The supplied `test.rex` demonstrates ordinary ooRexx finite-decimal materialisation of `i/(3*i)`. At default precision, `(i/(3*i))*(3*i)` prints values such as `5.99999999` and comparison is false for cases 6 through 9.

v0.7 expresses the same mathematical intent as:

```rexx
f = .Maths~fraction(i, i*3)
x = f * (i*3)
```

For every `i=1..25`, `f` is exact canonical `1/3` and `x` is exact `.MathInteger(i)`. No tolerance or decimal materialisation is used.

## Root-relative test invocation

With dependency paths present, package-root invocation is rechecked successfully, including `rexx tests/test_decimal_expansion.rex`.


## v0.7 quantization regressions

- `.MathDType` differentiates exact integer storage from approximate binary compute dtypes;
- `SYMMETRIC_INT8` retains block size, nearest-even rounding, exact per-block scales and exact reconstruction-error evidence;
- a representative exact matrix exposes `maxAbsError = 1/254` and proves/disproves caller-supplied error bounds without tolerance arithmetic;
- `[1,100]` demonstrates that block partitioning changes reconstruction error and that isolated blocks can eliminate the small-value outlier error;
- NF4 retains all 16 declared codebook values, including exact zero and normalized endpoints;
- NF4 reconstruction error is replayed exactly against the declared codebook and stays within the exact code-cell bound;
- quantized matrix `*` remains usable through an explicit dequantization path;
- nested/double quantization requests fail closed in PURE rather than being silently treated as ordinary NF4;
- mixed-precision plans preserve exact values and protected roles, keep tensors below the configured threshold high precision, and retain an explicit outlier threshold.
