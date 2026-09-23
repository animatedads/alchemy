# Body-worn-style reconstruction probe

Source qualification clip: `1000060474.mp4`, about 42.05 seconds / 1259 frames at approximately 30 fps, portrait display orientation.

This is intentionally opportunistic capture rather than an ideal photogrammetry orbit: walking motion, rapid turns, lingered points of interest, door/corner inspection and incomplete views.

## Cheap observation pass

A deliberately crude 5-bit stand-in surface was used only to test the proposed processing economy. It is **not** claimed to be the authoritative V5V raw-to-palette reducer.

- surface: 55 x 98 = 5,390 samples/frame
- value field: 5 bits/sample = 26,950 bits/frame before headers/deltas
- 4 Hz qualification sampling: 168 observation frames
- selected coarse keyframes: 34 (20.2% retained)
- raw RGB-equivalent sample-value ratio: about 1846.6:1 versus 1080 x 1920 x 24 bits

At a 4 Hz observation cadence the base value field is about 107.8 kbit/s before V5V temporal delta coding. This is a processing-observation figure, not a claim that it substitutes for the authoritative source video.

## Resolution survival probe

One-frame-per-second geometry matching over the same clip, after coarse spatial reduction and 5-bit-like quantisation, gave:

| base width | base surface | median detected features | adjacent pairs with >=8 geometric inliers |
|---:|---:|---:|---:|
| 55 | 55 x 98 | 58 | 8 / 41 |
| 96 | 96 x 171 | 137 | 16 / 41 |
| 128 | 128 x 228 | 219 | 16 / 41 |
| 192 | 192 x 341 | 250 | 22 / 41 |

The important result is not that 55 x 98 solves every pair. It does not. It provides a very cheap first-pass surface from which useful/poor intervals can be distinguished and selected evidence can be escalated.

## High-resolution return-to-source probe

The 55 x 98 pass selected 34 keyframes. High-resolution feature/pose work was then attempted only between the 33 adjacent selected keyframe pairs.

- 15 / 33 pairs produced at least 8 pose inliers
- 5 / 33 produced at least 20 pose inliers
- 470 pair-local points triangulated in the exploratory harness
- particularly strong evidence occurred around 9.0 -> 10.75 s and 31.25 -> 33.75 s

Pairs with insufficient geometry are not filled in by invention. They become candidates for a different view, a higher-resolution request, or remain unresolved.

## ooRexx / Maths v0.8 real-video qualification

The 9.0 s -> 10.0 s pair was retained as a fixture because it had strong correspondence evidence. Approximate pinhole intrinsics and a measured two-view relative pose were converted to the explicit right-handed/Y-up convention used by the reconstruction class. Forty inlier pixel correspondences were then handed to ooRexx.

The ooRexx path performed:

`pixel -> Vision3DCameraModel -> MathRay3D -> closest-ray triangulation -> acceptance gate -> VisionAdaptiveGrid3D`

Observed result:

- fixture matches: 40
- accepted at maximum ray separation 0.05 relative units: 37
- rejected: 3
- occupied sparse grid cells: 35
- mean closest-ray separation across the 40 supplied matches: about 0.0323 relative units

`bodycam_pair_9_10_oorexx_grid.ply` is a diagnostic projection of those occupied cells. It is **not** a globally fused or metric room mesh.

## Current boundary

The package now proves the low-data / selective-enhancement architecture and real-video ray-to-grid path. A globally coherent room reconstruction still needs a pose-chain / bundle-adjustment stage and a trustworthy metric-scale source. Those are deliberately not fabricated from this probe.
