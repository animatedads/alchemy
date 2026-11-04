# Power SLAM v0.14 — approximate northern-shore camera poses

Architecture: Tom Dyer. Implementation and native test: ChatGPT GPT-6, 2026-11-02. Rasen Falcon lane: `power-slam-harbour`.

## Inputs and lineage

- `1000066483.jpg`: north/eastern-shore view, camera seed **user-provided** `(-33.848849,151.213921)`; SHA-256 `1b3626e7e706bac2d47421617552b4ada58e07c0ce1c13b74d15c0ceeaac7312`.
- `1000066485.jpg`: Blues Point reserve-foreground/bridge/CBD view; SHA-256 `43041d255821e276c318ae2b3667be4a0344474cb95044c189a73c9eb4ce6e49`.
- Published Blues Point Tower building *approximate reference centre* `(-33.8490006,151.203533)`, 83 m building height; Dictionary of Sydney https://dictionaryofsydney.org/building/blues_point_tower . This does NOT prove the webcam is on that building.
- Google Earth **user roof interior** pins NW `(-33.849759,151.211889)`, NE `(-33.849915,151.212276)`, SW `(-33.854271,151.209068)`, SE `(-33.854422,151.209463)`: intentionally not surveyed tower centres, edges, or corners.
- Each photo is 1536 × 709 with black sidebands of approximately 138 px each; 1260 px is the active photographic image width. Native projection uses the full canvas with principal point x=768 but FOV is reported across 1260px, **not** 1536px.
- Photos are never distributed to GitHub; saved local preview overlays refer to the user-provided photographs and are only user-facing artefacts.

## Native ooRexx v0.14 pose hypotheses

Code: `SlamHarbourOtherCameraFit.cls`; execution `fit_other_cameras.rex`; native qualification `test_other_cameras.rex`.

| Camera hypothesis | Fitted latitude, longitude | Z above sea level | Heading | Pitch | HFOV (active image) | Held-out error | Decision |
|---|---|---:|---:|---:|---:|---|---|
| Blues Point Tower vicinity | **−33.8488623, 151.203338** | **66.8 m** | **150.3°** | −1.79° | **110.1°** | Arch **72.5 px**, Opera **29.1 px**, Salesforce **151.4 px** | **BLOCKED**: candidate reaches exploratory XY boundary, distant features contradictory |
| North shore, Jeffrey Street vicinity | **−33.8487411, 151.214266** | **79.0 m** | **206.2°** | +1.75° | **80.8°** | Arch **33.9 px**, Opera **26.7 px**, Salesforce **40.7 px** | **BLOCKED**: independent arch holdout fails 25px threshold; actual building footprint unverified |

Focal px on the full canvas: 440px (Blues) and 740px (north). Fitted XY solutions are *numeric hypotheses within provisional rectangular search windows*, not proof that either optical centre is on an accessible building or land. Source landmark pixel annotations are assistant-estimated with explicit uncertainties and may misidentify deck lines.

Blues Point: bridge-pylon top/deck points fit within a few pixels but independent scene features disagree badly, so the fitted 66.8 m height is not credible to metre precision. The image's park foreground argues for an elevated camera; Blues Point Tower is a testable nearby candidate, not an accepted installation site. Consider approximately **60–100 m ASL and HFOV around 100–120°** as an exploratory envelope, not statistical confidence intervals.

North shore: the 3D model approximately reproduces bridge towers, the arch, the Opera House and a prominent tower. The candidate lies about 34 m east and 12 m north of the user's original position, but none is an authoritative surveyed lens position. Suggested search area roughly **50–100 m radius** around the user's seed, elevation **60–95 m ASL**, optical HFOV **75–95°**; provisional exploration bounds rather than calibrated confidence limits.

## Qualifications and stopping conditions

Executed on ooRexx **5.3.0 r13196** with `rxmath`: **38/38 native v0.14 checks PASS**. Prior v0.13 source/qualification remains separate. The bounded native photographic fits completed, scored four pylon roof/deck controls, and evaluated three distinct distant holdout controls per camera. Both **FAIL** the real-photo qualification gate. 

Core risks: manually read pixel positions, pylon roof-interior rather than centres, illustrative deck proxy Z=50 m, unsurveyed sea level datum and rooftop polygons, approximate 3D Opera geometry, ambiguous Salesforce tower correspondence, and non-physical camera XY candidates. **Do not use either numeric fit to produce metre-accurate ferry positions or speeds.**

Next: identify actual supporting rooftop/building from oblique image plus GIS building footprints; independently measure bridge arch curve and ground-controlled shoreline; create photo-to-map correspondence data, then fit/holdout with real image distortion. Ferry recognition remains owned by `tombstone-vision` and must preserve unknown real-world coordinates until admission.