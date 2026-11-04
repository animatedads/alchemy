# Moonsault Sun + Moon ephemeris provider, dev1 (ooRexx 5.3.0 r13196)

Architecture: Tom Dyer. Additive implementation: ChatGPT (GPT-6), 2026-11-04.

## Call

```rexx
result = .MoonsaultEphemeris~sunMoon('2026-11-02T18:00:00Z', -33.8688, 151.2093)
sun  = result['sun']
moon = result['moon']
say moon['altitudeTrueDeg'] moon['azimuthTrueDeg'] moon['illuminatedFraction'] moon['visibilityCandidate']
::requires 'MoonsaultEphemeris.cls'
```

- UTC is required, strict ISO 8601 `YYYY-MM-DDTHH:MM:SSZ` (1900–2099); latitude/longitude degrees, eastern longitude positive.
- Both bodies return `altitudeTrueDeg`, `azimuthTrueDeg`, `altitudeRefractedDeg`, `azimuthRefractedDeg`, `refractionCorrectionDeg`, `aboveHorizon`, `visibilityCandidate`, `headingCandidate`, `method`, and model error allowance.
- Moon also returns `phase`, `elongationDeg`, `illuminatedFraction`, `distanceEarthRadii`, `horizontalParallaxDeg`, `visibilityReason`.
- **Predictions only**: result `status=PREDICTION_ONLY`, `sourceTag=MOONSAULT_PREDICTED`, `observationIndependent=false`. No photographic heading, GPS or aircraft position are inferred.
- `headingCandidate` for Sun requires true centre >=5° above ideal horizon. For Moon it requires >=5°, >=5% phase, and Sun below civil twilight (-6°). Geometric availability may differ from actual visibility due to atmosphere, camera clipping, glare, terrain and cloud.
- Refraction: Bennett model 1010 hPa/10°C, not applied below -1° true altitude. These outputs are *apparent under standard atmosphere*, not observations. The Moon has an additional altitude parallax correction based on distance in Earth radii (spherical sea-level approximation). Moon azimuth parallax corrections are omitted.
- Moon phase is geometric; illuminated fraction is not a photometric brightness estimate.

## Maths

Default trig comes from ooRexx `rxmath`; the optional `MoonsaultMathsTrig.cls` adapter routes sin/cos/tan through the project's `.Maths~angleDegrees(...)` API, without forking Maths:

```rexx
::requires 'MoonsaultMathsTrig.cls'
ignore = .MoonsaultAngle~setTrigProvider(.MoonsaultMathsTrig)
```

Shared `Maths.cls` must be on `REXX_PATH`. Inverse angles and square roots continue using existing ooRexx rxmath. The shared Maths adapter's end-to-end performance/precision is not claimed until run with the deployed Maths version.

## Model and validity

Low-precision orbital elements and perturbation terms from Paul Schlyter: https://stjarnhimlen.se/comp/ppcomp.html ; mean obliquity; sidereal time; spherical topocentric lunar altitude; Bennett refraction. UTC is used as approximate UT1, not a precision time-scale model.

Model allowances: Sun 0.10°, Moon 0.50° (conservative provisional engineering allowances, **not** certified global guarantees). Errors can rise near the horizon and with unmodelled refraction. The ephemeris must never be mistaken for a camera-observed bearing. Only SLAM450 can write `SUN_HEADING` / `MOON_HEADING` after an independent camera disc observation.

## Qualification

- Tested under ooRexx interpreter extracted from supplied 5.3.0 r13196 .deb.
- Six cases: Sydney (2026-11-02 12:16 UTC, 2026-11-01 19:58 UTC, 2026-11-02 00:00 UTC), London (2026-11-04 12:00 UTC and 2026-06-21 12:00 UTC), Melbourne (2026-11-02 04:00 UTC).
- Independently calculated reference: Swiss Ephemeris 2.10.03, topocentric, 1010 hPa/10°C, sea level.
- 24 angular checks: Sun absolute error <0.006°, Moon <0.037° in these six test cases. Regression thresholds 0.10° Sun / 0.30° Moon are **test tolerances**, not general accuracy guarantees.
- J2000 epoch JD 2451545.0, Sydney pre-dawn Moon visibility candidate true/Sun false, Moon-below-horizon candidate false.
- No real camera detection tested. No navigation accuracy claim. Provider is calculation-only; no SQLite or network dependency.

## Run

```sh
export REXX_PATH="$PWD/src:$REXX_PATH"
rexx tests/test_ephemeris.rex
```

The SLAM450 clock, panorama discs, camera observations, solar glare and flight-book audit are separately owned tasks.
