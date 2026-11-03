# Coupled second-order linear dynamics — ooRexx Maths v0.11

## Mathematical boundary

`MathSecondOrderLinearSystem` owns numerical propagation of constant-coefficient systems

```text
M x'' + C x' + K x = f(t)
```

It does not decide what a coordinate represents. A Physics consumer may interpret the coordinates as string modes, body modes or mechanical degrees of freedom; another consumer may use the same object for structural, control or circuit-equivalent systems.

## Integrators

Two schemes are explicit:

- `SYMPLECTIC_EULER`: velocity is advanced from the current acceleration, then displacement from the new velocity. This matches the current Physics World dev43 guitar step semantics and allows an acceleration migration without changing the numerical method.
- `NEWMARK_AVERAGE_ACCELERATION`: beta=1/4, gamma=1/2. For constant M/C/K, the effective matrix is factorized once by the native provider.

Integrator choice is included in derivation/evidence and preserved during independent replay.

## Providers and proof

PURE/REFERENCE execute through ordinary Maths matrix/vector operations. Under RATIONAL, closed discrete arithmetic remains exact.

The optional `SCIPY` provider accepts BINARY64 only. It uses NumPy arrays plus SciPy LU factorization/solve and records:

- provider versions and paths;
- configured BLAS/LAPACK identity;
- selected integration algorithm;
- equilibrium residual infinity norm;
- kinematic displacement/velocity residual infinity norms;
- mass-matrix condition number;
- effective-matrix condition number for Newmark.

`INDEPENDENTLY_REPRODUCED` proof replays the same declared integrator through REFERENCE, which uses a different ooRexx linear-solve implementation. A successful replay supports numerical consistency of the discrete calculation; it is not a claim that the physical model itself is correct.

## Final-state fast path

`integrateFinal` is distinct from `integrate`. It asks the provider to return only the terminal displacement/velocity/acceleration. This matters for foreign acceleration: crossing a complete large trajectory from Python back into ooRexx can dominate the calculation. The current six-string benchmark moved from roughly parity when materialising the whole history to about 50x faster when only the terminal state was required.

## Current Physics World dev43 guitar check

The validation fixture projects the current six-string mechanics into 32 generic DOFs (30 string modes plus 2 body modes), preserving current bridge/nut coupling and the current symplectic-Euler scheme.

Sealed-artifact qualification rerun:

```text
Physics local loop       10.624635 s
Maths SCIPY final-only    0.214728 s
Speedup                  49.4795 x
max |displacement diff|   8.3e-11
max |velocity diff|       6.8e-8
equilibrium residual      6.94e-18
```

The state comparison uses declared binary64 migration tolerances; it is not exact equality. The residual applies to the represented native discrete equations. See `VALIDATION_PHYSICS_DEV43_DYNAMICS.txt` for the sealed-artifact rerun.
