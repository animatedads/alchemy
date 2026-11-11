# Moonsault — five 9-Nov-2026 Sydney Harbour night screenshots

**Scope:** Direct native ooRexx PNG decoding and ooRexx-owned point detection,
registration, temporal tracking and aircraft-streak proposal. This is a
Measurable still-image experiment, NOT a successful full star identification or
certified heading/position fix. Broadcast screenshots are not included.

## Inputs

Five 1920x1080 PNG screenshots from the same webcam, timestamped in the
pixels at Sydney local 2026-11-09 20:17:25, 20:24:30, 20:32:05, 20:32:17,
20:37:11. Delta seconds from first: 0, 425, 880, 892, 1186.

Screenshots contain video-player overlays (title, playback controls, watermark,
progress and a thumbnail in 20:32:05). The pixel-space sky evidence scan
restricts itself to x=55..1855 and y=68..315, avoiding skyline and player
chrome. This conservative rectangular mask does not sample low-elevation
stars and is configurable per camera/recording.

## Executed test

Code: `src/MoonsaultStillPointScan.cls` with native media decoding through
`MediaPngFile.cls` and shared `.MediaRasterPlanes~luma(...)`.

| Sydney time | Compact point proposals | Registered skyline shift |
|---|---:|---|
|20:17:25 |3 |reference|
|20:24:30 |9 |(0,0)|
|20:32:05 |11 |(0,0)|
|20:32:17 |11 |(0,0)|
|20:37:11 |9 |(0,0)|

Detection uses single-pixel strict local maxima, local eight-point background,
minimum local contrast of 15 on 8-bit BT.709-approximate luma, and neighbour
peak sharpness. Registration minimizes sampled absolute luminance error over
stable skyline facades in +/-5 integer pixels. It does NOT assert subpixel
alignment or estimate photometric calibration.

Three coherent **5/5** observed point tracks were found by evaluating
endpoint-derived constant pixel velocities over all intermediate timestamps:

|First (x,y)|Last (x,y)|RMS positional prediction error across 3 intermediate frames|
|---|---|---:|
|(917,147)|(877,193)|0.472 px|
|(564,189)|(519,207)|0.777 px|
|(851,235)|(806,274)|0.320 px|

This is strong temporal *star-candidate* evidence; could still require
additional camera/CCD artefact controls. No named star identification is
claimed. No inertial/celestial heading is issued.

**Transient:** at 20:32:17, a group of four local peaks at x=317..322,
y=260..263 occurs as a single-frame elongated cluster. This is consistent
with the user's observed aircraft streak and deliberately excluded from the
five-frame tracks. The algorithm reports `MULTI_PEAK` rather than asserting
an aircraft identity from pixels alone.

## Reproduction

Using ooRexx 5.3.0 r13196 and the Media Object Access dev5 native packages:

```
rexx tests/test_still_tracks_synthetic.rex
rexx tests/test_sydney_20261109_stills.rex /path/to/screenshots /path/to/output
```

Output TSVs: `sydney_stars_candidates.tsv`,
`sydney_fiveframe_tracks.tsv`. No Python, FFmpeg command, image-processing
subprocess, or SLAM450 dependency. Next independent qualification: camera
intrinsics and Yale catalogue plate matching, tracking of false hot pixels,
cloud/satellite/aircraft classification and full plate residual audits.