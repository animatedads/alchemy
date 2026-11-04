# Tombstone Sydney v0.13 — lower-hull water-contact proxy

Architecture: user. 31 October 2026. Additive ferry-CV qualification; no changes to SLAM core.

## Real video observations

Two original fixed-webcam mobile H.264 recordings (31.0 s Manly, 25.9 s earlier), 288 blind-track frame candidates total. The earlier detector used the centre of the moving yellow component as if it were the hull contact with the harbour. This is geometrically wrong.

The new `estimate_contacts.py` reads original video frames sequentially and, without new vessel seed coordinates, looks for the lower boundary of warm-coloured hull pixels in the central 44% width of the independently tracked object. HSV gate: hue 5–43, saturation >=43, value >=48; row occupancy smoothed [0.25,0.5,0.25], occupancy >=0.20, candidate below yellow-centroid + max(2px,0.1 component-height). The final qualifying row +2px is a **lower-hull edge proxy**, not a surveyed waterline. It rejects any frame lacking usable evidence; it never invents contacts.

| Measurement | Manly recording | Earlier recording |
|---|---:|---:|
| Frames with proxy | 158/158 | 130/130 |
| Median downward offset | 12.95 px | 12.0 px |
| Original centroid net displacement (v0.12 rough metres) | 103.34 m | 110.36 m |
| Corrected proxy net displacement | 96.74 m | 105.36 m |
| Change | -6.39% | -4.54% |
| Corrected average **net** projected rate | 3.12 m/s | 4.07 m/s |
| Median mapped coordinate shift | 21.45 m | 14.52 m |
| +/-3 px model-only position sensitivity (median) | 4.53 m | 3.49 m |

All metre values depend on the **APPROXIMATE_UNSURVEYED** v0.12 camera estimate; systematic camera/geographic uncertainty is not captured by the +/-3px sensitivity. A frame-by-frame *path-length sum* is especially sensitive to image jitter and must not be presented as vessel distance. The storyboard shows detector centre in magenta and lower hull-contact proxy in green.

## Reproduction and qualification

1. Run `estimate_contacts.py` against both original user video recordings and v0.11 `unseeded_candidates.psv` for each video; it emits `{label}_pixels.psv` and `{label}_audit.psv`.
2. Run `qualify_contact.rex` with the v0.11 raw detection PSV, new audit PSV, new pixel PSV and output qualification PSV. Native ooRexx 5.3.0 r13196 passed **13/13** qualification cases, including replay and eleven deliberately corrupted records rejected.
3. Run the unchanged v0.12 `approx_water_plane.rex` with `camera_axes.psv` to transform newly estimated pixels onto the **rough** mapped water plane; run `compare.py` for before/after metrics.
4. Independently inspect `contact_point_storyboard.jpg` and `native_qualification.json` from the local conversation ZIP.

Video SHA-256: Manly `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`; earlier `6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb`. The two original videos are omitted from Git to avoid committing 157 MB of user media.

## Limits

These are conditional CV features of previously tracked candidates, not independently confirmed ferry identities. The warm-colour boundary can be affected by wake, reflection, hull occlusion, compression and viewing angle. No geographic survey, SLAM `TESTED` graph-edge promotion, native image recognition, source-owner acceptance or deployment is claimed. The next useful qualification is a genuinely held-out annotated hull-waterline set plus independent shoreline controls.