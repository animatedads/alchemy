# Power SLAM Harbour — Blues Point Tower as real 3D model geometry (v0.19)

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. 2 November 2026.

**This increment is native ooRexx source and an actual SVG panorama. No image-generation service was used.**

User identified the distinctive western high-rise seen as the north-shore PTZ pans across the harbour as **Blues Point Tower**, a previously considered webcam-location hypothesis and now an independent point/structure for pan alignment.

## Admitted source data vs provisional display values

- Feature `BLUES_POINT_TOWER`, Dictionary of Sydney mapped point `(-33.849000568058, 151.20353302224)`, 83m **building height above the ground**. Source: <https://dictionaryofsydney.org/building/blues_point_tower>.
- Independent OSM/Mapcarta polygon references use an alternative centre (`-33.84921, 151.20321`) and 82m height. Their mismatch with the Dictionary source must be resolved against survey/roof polygon before metric 3D qualification.
- Display rectangular footprint **24m x 20m**, oriented in local east/north axes, **UNSURVEYED**. Not measured from the current user screenshot. Not appropriate for high-confidence corner-point image matching.
- The base elevation above sea level is **unknown**. An explicit `baseASL` argument is mandatory to instantiate any cuboid. The supplied *display* render chooses zero as an illustrative datum, making the top **83m assumed ASL**. This is **not** a surveyed rooftop elevation. The height of the building **above ground** is 83m and remains correct regardless of baseASL.
- Rooftop reference point `BPT_ROOF` and base `BPT_BASE` are derived by `HarbourScene~local`. `CAMERA_POSE_ADMISSION=NOT_ADMITTED`.

## ooRexx integration

- `SlamHarbourBluesPointTower.cls`: class `HarbourBluesPointTower`, `catalogue` and additive `apply(scene, baseASL)` methods; duplicate IDs fail closed.
- `SlamHarbourPanorama.cls`: existing renderer now recognizes colour `#7c3aed` and labels `BPT_ROOF` only when that feature is added. Rendering of earlier scenes is unchanged.
- `bin/render_ptz_blues_tower.rex`: uses `HarbourQuayInfrastructurePanorama`, applies `HarbourBridgeRoofPins`, `HarbourBridgeVertical`, and then the Blues Point Tower. The transferred north-shore PTZ camera site `(-33.8487411,151.214266)` and 79m camera elevation remain **unqualified working hypotheses**.
- The rendered tower is at bearing **268.331527°** and ground distance **991.076m** from that provisional camera site. No claim is made about the real PTZ motor angle or actual optical centre.
- 30 scene cuboids; 540 SVG polygons, XML validated. `ptz_model_with_blues_tower.svg` is the direct native ooRexx output. PNG is rasterized using CairoSVG directly from that file, not rendered by an LLM/image generator.

## Actual native qualification, ooRexx 5.3.0 r13196

```
REXX_PATH=src rexx tests/test_blues_point_tower.rex  # 22 PASS
REXX_PATH=src rexx tests/test_harbour_panorama.rex # 36 PASS
REXX_PATH=src rexx tests/test_harbour_wharves.rex # 145 PASS
REXX_PATH=src rexx tests/test_quay_infrastructure.rex # 40 PASS
REXX_PATH=src rexx tests/test_bridge_vertical.rex # 38 PASS
REXX_PATH=src rexx bin/render_ptz_blues_tower.rex output.svg
```

**281/281 total checks passed.** This is geometry and renderer qualification, not an accepted pose fit. The static tower can now be used to test the PTZ pan bearing; a reliable roof-height measurement and a verified screenshot-to-tower correspondence are still required for accurate elevation/focal fitting. All image observations and ferry world coordinates remain provisional.