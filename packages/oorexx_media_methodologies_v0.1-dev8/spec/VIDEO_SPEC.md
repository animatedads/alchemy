# Video Processing Methodologies

The baseline catalogue contains **84 video methodologies**. They are intentionally spread across several families so the system can choose and compose methods according to the observation mechanism instead of routing everything through “enhance video.”

## Acquisition and camera model

The acquisition layer preserves decoded PTS and codec/source identity, then optionally provides declared transforms for colour linearisation, exposure normalization, distortion, chromatic aberration, interlace, cadence and rolling shutter. A corrected frame remains derived from the source frame.

## Camera state

Global stabilization, camera-motion authority gating and scene reacquisition are separate concepts. Stabilization makes a derived view; authority gating determines whether a fixed-scene measurement is valid; reacquisition establishes a new camera epoch/registration after movement.

## Restoration and enhancement

The catalogue includes temporal median, motion-compensated temporal denoise, non-local patch methods, BM3D-style methods, wavelets, deblocking, deringing, local contrast, illumination separation, HDR/exposure fusion and focus stacking.

Methods intended only to make a pattern easier to see use `VISUALIZE` authority. They cannot create new evidence.

## Motion measurement

Methods include frame difference, background subtraction, KLT-style sparse tracking, dense flow, block motion, phase correlation, feature matching, trajectory association, silhouette tracking, periodicity, phase-based subpixel motion, Eulerian magnification, rolling-shutter vibration and motion segmentation.

Motion measurement should normally occur before semantic classification. “Something moved coherently” and “that was a person/car/door” are different evidence levels.

## Structure measurement

Vision-style value-distance boundaries and line continuity are included explicitly. Their topology belongs to the declared sampling lattice; a HEX surface must not silently be processed with RECT adjacency.

## Reconstruction

There are 21 video reconstruction methodologies in the initial catalogue. They range from classical deconvolution and multi-frame super-resolution to experimental blur-envelope/tomographic reconstruction and synthetic model-assisted methods. See `RECONSTRUCTION_SPEC.md`.

## Geometry and 3-D

Methods include intrinsic calibration, pose estimation, homography, vanishing points, stereo, structure from motion, bundle adjustment, plane fitting, depth from motion, model-assisted monocular depth, shape from shading, photometric stereo, silhouette constraints, temporal registration, camera-path feasibility and occlusion reasoning.

This family aligns naturally with Vision 3D and Photo World, but methodology identity does not transfer their authority into this package.

## Forensic/provenance methods

Compression maps, encoding-history hypotheses, duplicate/drop analysis, GOP audit, visible-clock mapping, sensor-noise consistency, illumination consistency, timestamp metadata audit and edit-discontinuity analysis are included.

Forensic methods are explicitly cautious: a detectable inconsistency can justify further examination without automatically proving editing, identity or cause.
