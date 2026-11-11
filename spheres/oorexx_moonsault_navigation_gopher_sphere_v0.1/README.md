# Moonsault Navigation — Gopher Sphere v0.1 (source continuity)

## Identity and authority

Canonical programme: Alchemy. Component lane: `moonsault` (Rasen Falcon). Source: `packages/oorexx_moonsault_v0.1` on GitHub `animatedads/alchemy`; draft PR #131. This sphere is a **retrieval/continuity document**, not a second executable implementation.

Moonsault owns celestial catalogues, predicted Sun/Moon/star geometry, evidence qualification and experimental sky-based camera calibration. Its numerical predictions are **not direct camera observations**. SLAM450 retains authoritative camera observations, flight control and navigation decisions. Media Object Access owns pixels, decoded frames and large-file seek semantics. Location Service owns versioned Place/building/jurisdiction objects and coordinate-reference resolution.

## Current measured baseline (2026-11-11)

The 10-Nov Sydney camera sample has 9 Yale-matched star tracks, each with six native MP4/H.264 observations. The baseline 9-star plate fits at 0.56850 px RMS and yields a provisional true azimuth 208.01903° and altitude +0.92962°. A three-landmark camera-position model places the observation near Kirribilli at latitude -33.848212 / longitude 151.215134. These are **model estimates**; no surveyed camera pin or 5 m location qualification has been proven.

The new `MoonsaultRecoveryEnvelope.cls` reports finite-grid angular-error feasibility for the ±1 NM dead-reckoning reacquisition objective. Its radius is conditional on input allowances, not independently measured accuracy. The 54-sample landmark perturbation stress test is explicitly not a confidence interval. Native ooRexx r13196 tests are recorded in `qualification/RECOVERY_INTEGRITY.md` and package documentation.

## Hard gates

- Separate predicted ephemeris from measured sky observations and rejected cloud/aircraft false positives.
- Preserve source-image timestamps vs MP4 replay/slider timestamps.
- No invented star identity or heading when plate fit/held-out evidence is inadequate.
- Approximate skyline/pylon point picks are not survey-grade 3D tie points.
- No independent ±1NM GPS-ground-truth verification has been supplied.
- Source files, reference astronomical catalogue and numeric test evidence may enter Git; user webcam pixels do **not**.
- 5 m SLAM450 visual performance does not automatically transfer to this fixed camera.

## Discovery / deployment status

This folder is an **authored GitHub sphere artifact**. Rasen Falcon `sphere_check` returned `UNKNOWN_SPHERE` for the previous Moonsault package identifier on 11 Nov 2026. Source commit, lane artifact link and active runtime registry publication are different steps; do not claim the runtime sphere resolves until independently checked.