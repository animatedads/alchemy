# SLAM450 <-> Moonsault Sun/Moon contract (2026-11-04)

Architecture: Tom Dyer. Moonsault implementation: ChatGPT (GPT-6). SLAM450 integration owner: Claude (Opus 5.5).

### Prediction call

`answer = .MoonsaultEphemeris~sunMoon(unixSeconds, estimatedLatDeg, estimatedLonDeg)`

- `unixSeconds` is an integer POSIX/Unix UTC timestamp (1970-2099), as supplied by SLAM450's race clock; the existing strict `YYYY-MM-DDTHH:MM:SSZ` UTC string is also supported. Conversion is in ooRexx and never uses local timezone. Leap seconds are not independently represented.
- Geodetic latitude north positive, longitude east positive, degrees. No GPS needed. The position input is an *assumption* from the book, NOT a measurement.
- `answer['sun']` and `answer['moon']` are ooRexx Directory objects.
- Each body returns `altitudeTrueDeg` (unrefracted elevation above mathematical horizon), `azimuthTrueDeg` (clockwise from geographic north), `altitudeRefractedDeg` (standard refraction), `azimuthRefractedDeg` (same as true, simplified), `headingCandidate`, `visibilityCandidate`, `aboveHorizon`, and `modelErrorBudgetDeg`.
- Moon additionally returns `phase`, `illuminatedFraction`, `horizontalParallaxDeg`, `distanceEarthRadii`, `elongationDeg`.
- The whole answer includes `status=PREDICTION_ONLY`, `sourceTag=MOONSAULT_PREDICTED` and `observationIndependent=false`.
- Refraction is standard atmosphere, lunar parallax is a spherical/sea-level altitude correction, no weather or obstruction model. No independent geodetic fix is claimed.

### SLAM450 observation path (SLAM-owned)

1. Given race UTC and book position, render Sun/Moon in 3D panorama from the flight attitude and true azimuth/altitude. Mark Sun glare and sensor saturation. Do not confuse sky-chart celestial North-up with local vertical.
2. Camera independently detects disc pixels under a calibrated lens/FOV, pitch and roll. Georeferencing prediction is *not* fed to the detector as an observed heading.
3. Derive heading from the camera's measured disc direction vs independent ephemeris prediction. Retain a residual and propagated angle uncertainty; reject poor geometry, overexposure, cloud ambiguity, horizon uncertainty and untrustworthy low altitudes.
4. Only SLAM450 publishes `SUN_HEADING` / `MOON_HEADING` as its own observed event. The flight-book auditor checks source tag, UTC, camera sample ID, model version, estimated position and angular residual.
5. Bound correction and keep dead reckoning in charge if no independent disc measurement. If Moon below horizon/insufficient illumination, *no Moon heading observation*.
6. Do not convert Sun/Moon altitudes into a 25 m position fix: at the view's 0.375-0.75 degree/pixel, positional information is at most a coarse line of position. Primary benefit is heading-drift correction.

### Benchmark isolation

HARBOUR SLAM-only four-seed 420-second tests: quad median 20 m and wing median 24 m; approximately 90% within 50 m. These are terrestrial visual/dead-reckoned benchmarks, not celestial results.

Haiku flight-book contribution was independently sourced `seen` targets, not authoritative aircraft position; `where` was about 98% dead-reckoning echo. Treat all Moonsault predictions as non-observed until the camera verifies them.

### Qualification

Moonsault's prior ISO provider compiled/executed through user-supplied ooRexx r13196 and passed its test_ephemeris.rex regression. Unix clock conversion passed seven boundary checks in a standalone Rexx conversion test; the branch adds tests/test_unix_slam450.rex for provider end-to-end equivalence (not yet run as part of this branch). An additional 96 body/time reference-case comparison against Swiss Ephemeris produced 0 angle-threshold exceedances. Neither test proves camera-identified discs or flight-book navigation improvement. No SLAM450 component has been modified by this change.
