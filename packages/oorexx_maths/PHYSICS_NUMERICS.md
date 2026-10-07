# Physics-derived reusable numerical foundations — ooRexx Maths v0.17

## Ownership boundary

Physics World is a consumer specification, not a source of mathematical authority. Maths owns reusable mathematical mechanisms; Physics owns physical meaning, units, constitutive laws, force/energy equations, material/body/string semantics, conservation rules and causal evidence.

## Foundations first identified from Physics dev26

v0.9 centralized generic mechanisms that had appeared locally in Physics:

- context-controlled `pi`, `sqrt`, trig, exponential/logarithmic and atan/atan2 functions;
- bounded one-dimensional and bilinear interpolation;
- sampled scalar mean/RMS/uniformity and selected-frequency Fourier projection;
- stable real/complex quadratic roots;
- a semantic simultaneous-linear-system wrapper over the established matrix solver.

These remain current and are independently useful outside Physics.

## Native signal/modal paths

The current Physics/guitar work repeatedly exercises vector/matrix state operations and sampled signals. v0.10/v0.11 therefore provide optional BINARY64 acceleration for:

- native RxMath C scalar functions where its precision can satisfy the context;
- NumPy vector add/subtract/scale/Hadamard/dot;
- matrix multiplication, matrix-vector multiplication and numerical solve;
- sampled mean/RMS and selected-frequency Fourier projection;
- real FFT;
- direct/FFT convolution for impulse responses;
- vectorized damped-oscillator-bank rendering.

Each provider path is evidence-bearing and remains independently replayable where the proof surface supports it. DECIMAL50 and exact contexts are not silently narrowed to binary64.

## Coupled second-order dynamics — v0.11

The current six-string mechanics exposed the next generic mathematical seam clearly:

```text
M x'' + C x' + K x = f(t)
```

This equation is reusable mathematics. `MathSecondOrderLinearSystem` therefore owns numerical stepping while Physics continues to construct and interpret `M`, `C`, `K`, forces, coordinates and energy/causal evidence.

Two integration schemes are explicit:

- `SYMPLECTIC_EULER`, matching the current Physics dev43 per-step guitar semantics;
- `NEWMARK_AVERAGE_ACCELERATION`, beta=1/4 and gamma=1/2, available as a deliberate alternative rather than a hidden substitution.

The optional SciPy provider factors constant matrices once and reuses the factorizations. It records residuals and conditioning. Independent proof replays the **same declared method** through the REFERENCE provider and a different linear-solver implementation.

`integrateFinal` avoids crossing an unused complete trajectory through Foreign Runtime. On the current 32-DOF / 1,200-step six-string fixture this changes the acceleration from roughly parity (full-history marshaling dominated) to about 50x faster for final-state workloads.

See `SECOND_ORDER_DYNAMICS.md`.

## Current Physics dev43 direct check

A current-dev43 projection preserves the present bridge/nut/body coupling and current symplectic-Euler scheme, then compares all final displacements and velocities against the actual Physics loop. The qualification-host working-tree run measured 10.624635 s vs 0.214728 s (49.48x) in the sealed-artifact rerun with `max |dx| = 8.3e-11` and `max |dv| = 6.8e-8`; native represented-equation residual was about 6.94e-18.

These are binary64 migration tolerances, not a claim of exact equality. Physics remains the authority for whether the projected mechanical model is the desired physical model.

## Deliberately retained in Physics

The following remain Physics-owned even when they contain substantial arithmetic:

- shallow-water/Rusanov flux and CFL rules;
- hydrostatic/aerodynamic force models;
- fracture/contact/landing-energy semantics;
- acoustic radiation and propagation models;
- string/bridge/body/speaker force construction;
- energy accounting and causal physical evidence;
- material, fluid and Units semantics.

## v0.15 selected-channel coupled dynamics

For coupled systems where a domain has few generalized inputs and observations
relative to the full state dimension, `.MathSecondOrderInputOutputSystem`
keeps the generic `B*u` forcing and `Hx*x + Hv*v` projection with the native
dynamics provider. This was checked against the current Physics World dev46.4
32-DOF guitar projection. Physics owns acoustic-force and pickup meaning; Maths
owns only linear channel mapping and numerical propagation.

## v0.16 reusable sampled LTI continuation

Inspection of the current Physics dev46.8 guitar block-feedback path and Rexx-tronics dev25 shows a further reusable seam after second-order mechanics: small or large sampled linear subsystems whose physical channel meaning remains outside Maths.  v0.16 adds generic discrete state-space recurrence and checkpointable continuation.  Physics and Rexx-tronics remain authoritative for pickup/circuit/amplifier/speaker/acoustic semantics; they may project an appropriate linearized sampled subsystem into Maths when useful.

Provider selection remains workload-aware.  A 2-state/12,000-sample native bridge case was much slower than scalar ooRexx because marshalling dominated, while a 32-state/1,200-sample generic matrix recurrence was about 15.8x faster through NumPy on the qualification host.

