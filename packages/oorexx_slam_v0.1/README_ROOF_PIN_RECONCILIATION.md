# Power SLAM Sydney Harbour: coordinate and rooftop reconciliation (v0.12)

Architecture: Tom Dyer. Implementation/evidence: ChatGPT GPT-6, 2026-11-01.
Rasen Falcon lane: `power-slam-harbour`. Complementary ferry-recognition lane: `tombstone-vision` (does not own SLAM geometry).

## Authoritative evidence hierarchy

Four manually dropped Google Earth pins, visibly inside pylon rooftops in user-provided screenshots. **NOT** surveyed pylon roof centres, dimensions, corners, GPS-grade fixes, or bridge steel-truss attachment points:

| Pylon roof pin | Latitude | Longitude | Evidence screenshot |
| --- | ---: | ---: | --- |
| NW | -33.849759 | 151.211889 | 1000066729.jpg |
| NE | -33.849915 | 151.212276 | 1000066730.jpg |
| SW | -33.854271 | 151.209068 | 1000066731.jpg |
| SE | -33.854422 | 151.209463 | 1000066732.jpg |

Local tangent-plane approximate separations from the independent pins:
- Northern transverse: 39.71 m, southern transverse: 40.14 m.
- West longitudinal: 565.27 m, east longitudinal: 564.44 m.
- Pylon-roof axis agrees closely with the pair transverse direction (near orthogonal).

Do not conflate these rooftop interior pins with the 30 m separation of the steel arch trusses or the roughly 49 m deck width. Those refer to **different structural features**.

`SlamHarbourBridgeAudit.cls`: retains the earlier inconsistent 4-coordinate hypothesis, independent pylon/lookout checks, and rejection evidence. `SlamHarbourBridgeSemantics.cls`: separates bridge arch, deck, pylons, abutments, lookouts, building polygons and user-pinned rooftop controls. `SlamHarbourRoofPins.cls`: accepts a *consistent non-surveyed rooftop-pin layout* while forbidding the promotion of pin coordinates or guessed 19x11m envelopes to surveyed corners.

## Camera fitting is NOT qualified

The real 1536x862 Cafe Sydney photo is still not solved. The current model's four selected pylon correspondences alone fit a camera at ~46.66 m ASL (31.55-degree FOV); adding the presumed Cahill foreground point gives ~31.28 m ASL (34.20-degree FOV). Those mutually incompatible heights and near-boundary camera positions make the calibration unacceptable. The model arch crown remains a non-fitting holdout; the photo landmark correspondences are provisional, as are the un-surveyed Customs House roof search polygon and rough Cahill cross-section. Both fits have `PHOTO_FIT_ADMISSION=BLOCKED_UNVERIFIED_IMAGE_LANDMARK_CORRESPONDENCES`.

**No real photographic pose, height ±2m, or reliable ferry positions can be claimed.** Do not use these hypotheses to train or qualify ferry motion / world-coordinate outputs. Tombstone Vision may consume only qualified landmarks/evidence with explicit uncertainty.

## Reproduce (ooRexx 5.3.0 r13196, rxmath)

With `SlamHarbourPose.cls`, `SlamHarbourPerspectiveFit.cls`, all three class files above, and tests in a common search path:

```sh
rexx test_bridge_audit.rex      # 19 PASS
rexx test_bridge_semantics.rex  # 27 PASS
rexx test_roof_pins.rex         # 29 PASS
rexx test_footprint_fit.rex     # 24 PASS synthetic fit
rexx fit_cafe_roofpins.rex      # two incompatible real-photo hypotheses; reject
```

The new tests check the coordinate claims and synthetic solver behaviour; they **do not** validate the camera against truth. The photographer's images/screenshots are not included in this public Git package.

## Next requirements

1. Extract roof polygon corners from *georeferenced imagery with stable ground control*, rather than interpreting dropped-pin centres as building centres.
2. Represent the steel arch (including measured crown and hanger profiles) and lower abutments separately from granite pylons.
3. Annotate actual pylon tops, bases, arch crown and foreground railing on the original webcam photo, with point IDs and uncertainty.
4. Constrain the camera XY within an independently mapped Customs House rooftop footprint, then fit XY, Z, yaw, pitch and focal length simultaneously.
5. Hold out independent landmarks, report reprojection errors and model uncertainty; never publish a precise camera pose merely because an optimiser converged.