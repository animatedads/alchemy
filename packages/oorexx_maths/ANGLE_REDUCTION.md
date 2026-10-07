# Angle reduction / precision boundary — v0.8 qualification note

The first v0.8 3D prototype appeared to have an angle-reduction/trigonometric defect. A 90-degree Z-axis quaternion rotated `[1,0,0]` to approximately:

```text
[0.000000000131909..., 0.999999999868090..., 0]
```

The high-precision pi value and Taylor recurrence were not the root cause.

## Root cause

In ooRexx, argument expressions are evaluated **before** the callee can establish its own `NUMERIC DIGITS` setting. Thus code shaped like:

```rexx
rx_math3d_sin(r / 2, ctx)
```

can round `r / 2` under the caller's precision before `rx_math3d_sin` runs.

The same issue affected unary operations. A quaternion with full-precision components could enter `conjugate`, but `-_z` would be rounded if negation occurred before an explicit working-precision boundary.

This is a general ooRexx numerical rule, not a trigonometry-specific defect.

## Repair rule

Every 3D method that performs arithmetic establishes the applicable Maths working precision **before the first arithmetic operation**, including:

- half-angle division;
- unary negation;
- vector dot/cross products;
- normalization;
- quaternion multiplication/inversion;
- matrix coefficient construction;
- perspective/orthographic coefficient calculation;
- ray/plane calculation.

The permanent regression deliberately enters the public API with caller `NUMERIC DIGITS 9` while using `.MathContext~decimal(50)`. The following must still retain the 50-digit Maths semantics:

- axis-angle quaternion construction;
- quaternion vector rotation;
- quaternion inverse/conjugate;
- angle halving.

## Reduction strategy

Degrees are reduced modulo 360 before conversion through pi. This is especially important for huge degree values because it avoids multiplying a huge number by an approximate pi before reduction.

Radian reduction uses a bundled >220-digit pi constant and selects working precision according to both the Maths context and the input magnitude. If the requested magnitude would require more trustworthy pi digits than bundled, the helper fails closed rather than claiming a high-precision reduction it cannot support.

After reduction to `[-pi,pi]`, sine/cosine use symmetry to reduce into a smaller interval and evaluate convergent Taylor recurrences at increased guard precision.

## Exact domain

Degree modulo reduction itself can remain exact in a rational context. Conversion through pi and trigonometric evaluation cannot generally remain rational, so those operations explicitly require a decimal/binary context.
