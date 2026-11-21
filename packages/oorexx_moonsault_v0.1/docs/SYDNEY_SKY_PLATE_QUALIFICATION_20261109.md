# Moonsault: Sydney 2026-11-09 stills, Yale catalogue hypothesis gate

**Status:** Native ooRexx development increment and executed validation. **No star identity or navigation correction qualified.**

## Code

- `src/MoonsaultStillPointScan.cls`: retains the original five-frame point tracker, adds four-frame temporal tracks and pixel-neighbourhood deduplication. Star detection remains independent of SLAM450.
- `src/MoonsaultSkyPlate.cls`: ooRexx Yale catalogue loader (full `ra,dec,mag,bv,spectral,hd,hip,dist_pc,name` schema or test `name,ra,dec,mag`), UTC timestamp conversion, J2000 to mean-of-date IAU 1976 precession, topocentric direction, gnomonic camera hypothesis, three reference-track fit, three withheld-track validation, and bounded FOV preselection. No Python, OpenCV, subprocess or external plate-solving service.
- Two named **approximate** pointing parameters, centre azimuth and altitude, are only search inputs. This component does not claim calibrated focal length, distortion, principal point, or camera geolocation.
- `test_precession_epoch.rex`: verifies J2000 identity and precession of RA0/Dec0 to Nov 2026 (+0.344107137 deg RA, +0.149508078 deg declination).
- `test_plate_synthetic.rex`: known synthetic six-star geometry in this model, integer centroid rounding; a three-star reference fit and three withheld stars; fails if a known-answer source is not recovered.
- `test_fourframe_tracks.rex`: original real PNGs, shared native Media Object Access dev5 RGBA32 decode/luma; deduplicates close peaks.
- `test_sydney_20261109_stills.rex`: original five-still track and aircraft-shaped multi-peak rejection regression.
- `test_plate_holdouts.rex`: real five-frame reference tracks and three additional four-frame tracks against a curated 114-row Yale subset.

## Actual source evidence

Five real 1920x1080 webcam screenshots dated 2026-11-09 Sydney AEDT 20:17:25, 20:24:30, 20:32:05, 20:32:17 and 20:37:11. Astronomical UTC start: **2026-11-09T09:17:25Z**. Camera pixel registration by stationary building features was (0,0) at integer precision in the five original stills; UI overlays are excluded by sky search bounds. The screen captures themselves, videos and colour-plane exports are **not included** in public source packages.

| Test | Observed result |
|---|---|
| 5-frame detections per still | 3, 9, 11, 11, 9 |
| Full 5-frame persistent tracks | 3, RMS 0.472, 0.777, 0.320 px |
| Four later screenshots | 7 raw track proposals, **6 distinct** after neighbouring-peak suppression |
| Four-frame unique RMS, pixels | 0.376, 0.485, 0.427, 0.510, 0.704, 0.371 |
| Aircraft-like transient | four neighbouring peaks x=317..322, y=260..263 in 20:32:17; no five-frame track |
| Synthetic known-answer | Nunki/Sargas/Kaus Australis reference RMS **0.426 px**; Shaula/Kaus Borealis/HD160578 held-out RMS **0.520 px** |
| Real broad-tolerance best hypothesis in SW subset (yaw 250 deg, alt 25 deg) | reference RMS **9.29 px**; two matched withheld candidates at **8.02 px RMS**; insufficient for a star identity |
| Authority | **UNQUALIFIED — zero heading corrections** |

The real-data catalogue names printed in `test_plate_holdouts.rex` are **hypotheses only**, not accepted matches. A fit using only three data points is prone to accidental catalogue coincidences. Held-out residuals around 8 pixels are much too weak to promote, particularly with unknown camera intrinsics and only a geographically/time-selected subset. The full 9,096-entry catalogue must be checked for competing alternatives before any claim of uniqueness.

## Important bug fixed

The first development attempt reused the `p` projection variable inside nested candidate loops. After testing a star through five epochs, a later candidate pair incorrectly used that star's *final* projection as its first-frame position. The synthetic regression exposed the error. The corrected method resets the reference coordinate per pair and uses separate temporaries for each epoch. All hypotheses emitted before this correction are invalid; the earlier raw image-point tracks remain valid.

## Limitations / next gate

1. A subset of **114** bright SW catalogue stars was used for repeatable native regression; production BSC input can load all 9,096 but must be prefiltered by camera field of view and magnitude to <=128 candidate stars before the bounded pair search. This is a *proof-of-method*, not a qualified scalable all-sky plate solver.
2. Camera location (-33.86, 151.21), bearing (250 deg), tilt (25 deg), and focal scale are provisional search values, **not measured camera calibration**. Camera optical distortion and actual WCS must be independently determined.
3. IAU1976 mean precession is implemented; proper motion, aberration, nutation, refraction and weather are not qualified. No inference of catalogue star IDs is authorised.
4. To qualify: independent in-field star features with photographic centroids, true camera calibration, full BSC competing hypotheses, 2+ withheld tracks below a defensible <=1.5 pixel RMS, physically checked apparent motion and ambiguity assessment. Require evidence beyond these five stills.
5. Broader camera-bearing grid search is intentionally not a release test; unoptimised repeated ooRexx trig sweeps are costly. Query-oriented sky-index preselection or NoSQLServer provider integration remains future work.

## Executed environment

- Uploaded local `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(2).deb`, unpacked in a private working tree (no system install).
- Existing Media Object Access dev5 native PNG/raster providers for colour/RGB->luma only.
- `native_qualification.log` contains the exact stdout from the current turn.
- `rexxc` translation/syntax check also passed for both new and extended ooRexx classes.

No data from the broadcaster has been committed to Git. Only software, a derived subset of public catalogue positions, numerical tracked coordinates and test records are in the development archive.