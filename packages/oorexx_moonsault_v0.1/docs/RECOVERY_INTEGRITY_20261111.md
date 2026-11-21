# Moonsault — angular feasible region and 1 NM recovery integrity, 11 November 2026

## Purpose

The user requires a **lost-dead-reckoning recovery** after an approximately 800 km journey, with an error target on the order of ±1 nautical mile (1,852 m). This is not equivalent to SLAM450's approximately 5 m visual-fix performance in a suitable 3-D scene.

## Implemented

`src/MoonsaultRecoveryEnvelope.cls` exposes two class methods:

- `evaluate(plate,JD,landmarks,fix,angularAllowanceDeg,searchRadiusMetres,gridStepMetres)` enumerates a bounded candidate region in a local East/North metre plane. For each cell, it recomputes celestial-derived landmark bearings at the candidate observer coordinate and compares these with independent geographic landmark bearings. All three must fall within the explicit angular allowance. Output includes scanned/feasible counts, East/North ranges, search-boundary touches, a finite-grid padded radius, and a **MODEL_ONLY** 1 NM status. It never returns surveyed accuracy or an independently certified position.
- `stress(plate,JD,landmarks,fix,pixelBudget,chartBudgetMetres)` performs 54 deterministic scenarios: 27 patterns of up-to-20-pixel image-pick changes, plus 27 patterns of up-to-25-metre chart-coordinate changes. It records maximum output-position shift **and** maximum residual. This is sampled sensitivity, not a statistical confidence interval or a proof over all allowable perturbations.

These are ooRexx classes. They preserve the authoritative `MoonsaultPlateIdentity` nine-star plate and `MoonsaultCameraFix` terrestrial bearing intersection. No external estimator or Python processing is involved.

## Native evidence

Executed with user-provided ooRexx 5.3.0 r13196 (internal test, 64-bit), extracted locally without installation:

- Nine Yale stars, real Sydney tracked pixels: fitted sky plate RMS **0.56850 px**, maximum **1.08066 px**.
- Coarse candidate **-33.848212° latitude / 151.215134° longitude**, axis **208.01903° true**, **+0.92962° elevation** (as per original baseline).
- Three approximate charted landmark positions and hand-picked image coordinates; largest measured landmark bearing discrepancy **1.4874°**.
- With explicitly assumed ±2° independent landmark-bearing tolerance, a 2,500 m radius / 50 m step circular grid sampled **7,845** points; only the centre qualified. The output uses a **70.71 m finite-grid padded radius**. Do **not** interpret that value as true uncertainty, a statistically derived confidence radius or proof that every continuously feasible position has been found.
- Deliberately too-tight ±0.1° tolerance produces **NO_FEASIBLE_POSITION**; no silent precision promotion.
- 54 sampled landmark perturbations produce a maximum position shift **68.27 m**. Some perturbations have a largest landmark residual of **6.46°**, and would be rejected by the ±2° policy; do not combine this with the grid as a confidence bound.
- Synthetic location constructed from a consistent sky-plate and three charted bearings is recovered without detected error in printed precision, with a **fourth independently withheld synthetic landmark** agreeing within **0.000927°**. This is an internal numerical known-answer check, not independent real-world geodetic ground truth.

## Gates and limits

1. `GRID_SAMPLES_WITHIN_ONE_NM_MODEL_ONLY` is a **conditional mathematical model result** with user-chosen angular budgets; it cannot certify ±1 NM ground accuracy.
2. 3D pylon positions, chart provenance, lens calibration, timestamp offset, refractive/astrometric corrections, camera installation location and independent camera survey remain insufficiently validated to claim a real-world accuracy bound.
3. Production 5 m SLAM450 fixes require separate surveyed 3-D tie points and image reprojection plus independent held-out checks; do not use the 5 m figure as a Moonsault measurement.
4. Moonsault remains the celestial prediction/catalogue provider. SLAM450 owns flight observations and resulting authoritative navigation decisions. Experimental webcam verification is evidence, not an automatic SLAM adapter approval.
5. A source-control Gopher sphere directory is not automatically a registered/available Rasen Falcon LLM Gopher sphere. Registration must be separately confirmed through the sphere resolver.

## Run

From this package's `tests` directory, with ooRexx configured (e.g. environment `REXX` pointing to its binary), execute:

```sh
rexx test_sydney_camera_coarse_fix.rex
rexx test_recovery_envelope.rex
```

The native execution receipt is `docs/native_recovery_integrity_r13196.log`.