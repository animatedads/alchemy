# Moonsault: Sydney webcam coarse navigation camera fix (10 November 2026)

## Status

**COARSE_NAVIGATION_CANDIDATE**. Not a survey position, not a claimed 5 m visual-SLAM fix. Bearing is given relative to true north. The desired navigation use is to reacquire position after dead reckoning drift of up to approximately ±1 nautical mile (1,852 m); no externally surveyed camera-location ground truth has been provided to validate a statistical ±1 NM guarantee.

## Camera sky calibration (native ooRexx)

The original unannotated 1920x1080 videos are from 10 Nov 2026, 21:04:30–21:10:00 AEDT (10:04:30–10:10:00 UTC). Starting from the 9 independently identified Yale catalogue stars and their first/end source-video pixel coordinates, `MoonsaultPlateIdentity~fit` solves the projective sky plate and rejects the known alternative patterns. Nine-star 330 s two-epoch reprojection: 0.56850 pixel RMS, 1.08066 pixel maximum.

The new `MoonsaultCameraFix~rayJ2000` solves a 3-D forward camera ray from the intersection of the projection's x=960 and y=540 planes. IAU 1976 **mean** J2000-to-observation-date precession converts that celestial ray into a topocentric true bearing using the sidereal time calculated for 2026-11-10T10:04:30Z.

**Axis at local Sydney location:** azimuth **208.02° true**, elevation **+0.93°** at the image centre. Minor unmodelled refraction, aberration, nutation, proper motion, magnetic declination and physical calibration remain out of this result. Do not confuse a pixel-fit residual with angular or geodetic accuracy.

## Three independent charted ground landmarks

A photographically chosen representative point in each region is transformed into the source-video 1920×1080 coordinate system. These points are approximate (landmark centres/pylons and video scaling are not surveyed image control points). The geographic coordinates were sourced from public landmark geodata; **they were not inferred from webcam-directory camera coordinates**.

| Landmark | Approximate map latitude, longitude | Source image x,y | Chart bearing from fit | Star-plate ray bearing | Residual |
|---|---|---|---|---|---|
| Sydney Opera House | −33.85680, 151.21530 | (211.39,625) | 179.080° | 179.368° | −0.287° |
| Harbour Bridge southern pylon group | −33.85454, 151.20926 | (1173.58,600) | 217.630° | 216.837° | +0.792° |
| Harbour Bridge northern pylon group | −33.85003, 151.21209 | (1682.36,600) | 234.283° | 235.770° | −1.487° |

Small-area East/North perpendicular-line least-squares intersection, iterated three times to account for longitude's effect on local sidereal time, returns:

**LAT −33.848212; LON 151.215134** (WGS84-like decimal geographic approximation). **Axis 208.019° true, +0.930° elevation**. Absolute landmark-bearing residual maximum 1.487°, showing the image/landmark centre selection is not survey grade. The physical candidate is in Kirribilli, northeast of the bridge.

The 0.5 km radius recommended for dead-reckoning reacquisition is a deliberately conservative engineering search envelope, **not** a calibrated 95% confidence region. Camera extrinsic/lens calibration, surveyed landmark 3-D positions and independent ground-truth control are required before asserting a statistically bounded ±1 NM operational performance or a 5 m SLAM450 position.

## Separation of responsibilities

- **Moonsault:** UTC, sidereal time, Yale identities, optical direction, bearing uncertainty.
- **World/location model:** map projection, 3-D landmark features, terrain, building objects, coordinate resource providers.
- **SLAM450:** measured image feature-to-world-object association, full 3-D ray intersections and sub-metre/pixel reprojection diagnostics. The previously reported ~5 m visual SLAM450 performance is not automatically inherited by this static-webcam solve.
- **Intention / navigation:** combine low-confidence celestial heading + coarse geospatial fix with dead-reckoning prior. Promote to visual precision only when tested 3-D geometry is available. Never report a recovered position without the supporting evidence and uncertainty class.

## Provenance

Webcam owner: https://webcamsydney.com/ . Landmark coordinate references: Sydney Opera House heritage nomination (−33.8568, 151.2153), OpenStreetMap-derived South Pylons (−33.85454,151.20926) and North Pylons (−33.85003,151.21209). Third-party live-webcam directories list inconsistent coordinates; a camera-location directory pin was **not** used as the fit input. No downloaded webcam photographs/video are included in the artifact or public repo.

## Reproduce

From `tests` with ooRexx 5.3 r13196 and the included core Moonsault class sources located in `src/`:

```sh
rexx test_sydney_camera_coarse_fix.rex
```

The new production source is `src/MoonsaultCameraFix.cls`. Tests reconstruct the 9-star plate from the original numeric track and Yale fixtures rather than using a pre-solved projection matrix.